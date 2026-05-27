--
-- PostgreSQL database dump
--

\restrict LCSXqM1cN6Tua55sdlOvpxIHgOadzFMeYztwOcEvpvGgeG8gUISrUAgZqZzmOU9

-- Dumped from database version 17.6
-- Dumped by pg_dump version 18.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: task_priority; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.task_priority AS ENUM (
    'low',
    'medium',
    'high'
);


--
-- Name: task_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.task_status AS ENUM (
    'pending',
    'inProgress',
    'completed'
);


--
-- Name: apply_rc_entitlement(timestamp with time zone, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.apply_rc_entitlement(p_expires_at timestamp with time zone, p_source text, p_store_tx_id text DEFAULT NULL::text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
declare
  v_user_id uuid := auth.uid();
  v_now timestamptz := now();
  v_current_expires_at timestamptz;
begin
  if v_user_id is null then
    raise exception 'unauthenticated' using errcode = '42501';
  end if;
  -- 'free_trial' is NOT in this whitelist on purpose — that source must only
  -- be set via start_free_trial(), which enforces the one-time-use rule.
  -- TODO: ideally redeem_promo_code() should write the subscription row
  -- itself so 'promo_code' could also be removed from here. Until that
  -- refactor lands, the 400-day cap below limits the worst-case damage if
  -- a hostile client tampers with expires_at after redeeming a 1-day code.
  if p_source not in ('play_store', 'app_store', 'stripe', 'promo_code', 'unknown') then
    raise exception 'invalid_source' using errcode = '22023';
  end if;
  if p_expires_at is null or p_expires_at <= v_now then
    raise exception 'invalid_expiry_past' using errcode = '22023';
  end if;
  if p_expires_at > v_now + interval '400 days' then
    raise exception 'invalid_expiry_far_future' using errcode = '22023';
  end if;
  if p_store_tx_id is not null and length(p_store_tx_id) > 200 then
    raise exception 'invalid_store_tx_id' using errcode = '22023';
  end if;

  -- Never shorten an existing entitlement: if the user already has a longer
  -- expiry (e.g. from a stacked promo code), keep it. Only extend.
  select expires_at into v_current_expires_at
    from public.subscriptions
   where user_id = v_user_id;

  if v_current_expires_at is not null and v_current_expires_at > p_expires_at then
    -- Just refresh source/store_tx_id without shortening.
    update public.subscriptions
       set source      = p_source,
           store_tx_id = coalesce(p_store_tx_id, store_tx_id),
           cancelled   = false
     where user_id = v_user_id;
    return;
  end if;

  insert into public.subscriptions (user_id, expires_at, source, store_tx_id, cancelled)
  values (v_user_id, p_expires_at, p_source, p_store_tx_id, false)
  on conflict (user_id) do update
    set expires_at  = excluded.expires_at,
        source      = excluded.source,
        store_tx_id = coalesce(excluded.store_tx_id, public.subscriptions.store_tx_id),
        cancelled   = false;
end;
$$;


--
-- Name: cleanup_rate_limits(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.cleanup_rate_limits() RETURNS void
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  delete from public.rate_limits where window_start < now() - interval '7 days';
$$;


--
-- Name: delete_user_account(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_user_account() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  -- Delete all user-owned data
  delete from public.transactions           where user_id = uid;
  delete from public.recurring_transactions where user_id = uid;
  delete from public.custom_categories      where user_id = uid;
  delete from public.subcategories          where user_id = uid;
  delete from public.subscriptions          where user_id = uid;

  -- Finally delete the auth user (cascades any remaining FK references)
  delete from auth.users where id = uid;
end;
$$;


--
-- Name: increment_ai_usage(uuid, date, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.increment_ai_usage(p_user_id uuid, p_date date, p_field text) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE v_result integer;
BEGIN
  IF p_field NOT IN ('voice_count', 'image_count') THEN
    RAISE EXCEPTION 'Invalid field: %', p_field;
  END IF;
  IF p_field = 'voice_count' THEN
    INSERT INTO public.ai_usage (user_id, date, voice_count, image_count)
    VALUES (p_user_id, p_date, 1, 0)
    ON CONFLICT (user_id, date) DO UPDATE SET voice_count = ai_usage.voice_count + 1
    RETURNING voice_count INTO v_result;
  ELSE
    INSERT INTO public.ai_usage (user_id, date, voice_count, image_count)
    VALUES (p_user_id, p_date, 0, 1)
    ON CONFLICT (user_id, date) DO UPDATE SET image_count = ai_usage.image_count + 1
    RETURNING image_count INTO v_result;
  END IF;
  RETURN v_result;
END; $$;


--
-- Name: increment_rate_limit(uuid, text, timestamp with time zone, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.increment_rate_limit(p_user_id uuid, p_endpoint text, p_window_start timestamp with time zone, p_limit integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
declare
  v_count integer;
begin
  -- Defensive: only the authenticated user can rate-limit themselves.
  -- The edge function passes user.id from auth.getUser(), but enforce again
  -- here in case the RPC is ever called from another context.
  if auth.uid() is null or auth.uid() <> p_user_id then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  insert into public.rate_limits (user_id, endpoint, window_start, count)
  values (p_user_id, p_endpoint, p_window_start, 1)
  on conflict (user_id, endpoint, window_start)
  do update set count = public.rate_limits.count + 1
  returning count into v_count;

  return v_count <= p_limit;
end;
$$;


--
-- Name: redeem_promo_code(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.redeem_promo_code(code text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_code_row   promo_codes%ROWTYPE;
  v_user_id    UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión para canjear un código.' USING ERRCODE = 'P0001';
  END IF;

  -- Lock the row for the duration of the transaction to prevent concurrent
  -- increments from racing. FOR UPDATE means only one caller proceeds at a time.
  SELECT * INTO v_code_row
  FROM promo_codes
  WHERE promo_codes.code = upper(trim(redeem_promo_code.code))
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Código no válido.' USING ERRCODE = 'P0001';
  END IF;

  IF v_code_row.valid_until IS NOT NULL AND v_code_row.valid_until < now() THEN
    RAISE EXCEPTION 'Este código ha expirado.' USING ERRCODE = 'P0001';
  END IF;

  IF v_code_row.max_uses IS NOT NULL AND v_code_row.use_count >= v_code_row.max_uses THEN
    RAISE EXCEPTION 'Este código ya no tiene usos disponibles.' USING ERRCODE = 'P0001';
  END IF;

  -- Insert redemption — unique(promo_code_id, user_id) constraint rejects duplicates.
  BEGIN
    INSERT INTO promo_code_redemptions (promo_code_id, user_id)
    VALUES (v_code_row.id, v_user_id);
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'Ya has utilizado este código.' USING ERRCODE = 'P0001';
  END;

  -- Atomic increment — safe because we hold the FOR UPDATE lock.
  UPDATE promo_codes
  SET use_count = use_count + 1
  WHERE id = v_code_row.id;

  RETURN jsonb_build_object(
    'type',                coalesce(v_code_row.type, 'subscription'),
    'duration_days',       coalesce(v_code_row.duration_days, 30),
    'discount_percentage', v_code_row.discount_percentage
  );
END;
$$;


--
-- Name: start_free_trial(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.start_free_trial() RETURNS timestamp with time zone
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
declare
  v_user_id uuid := auth.uid();
  v_trial_days constant integer := 4;
  v_now timestamptz := now();
  v_expires_at timestamptz := v_now + (v_trial_days || ' days')::interval;
  v_existing record;
begin
  if v_user_id is null then
    raise exception 'unauthenticated' using errcode = '42501';
  end if;

  select trial_used_at, source, expires_at
    into v_existing
    from public.subscriptions
   where user_id = v_user_id
   for update;

  if found and v_existing.trial_used_at is not null then
    raise exception 'trial_already_used' using errcode = 'P0001';
  end if;
  -- A paid/promo subscription is already active → no reason to start a trial.
  if found and v_existing.source is not null
     and v_existing.source <> 'free_trial'
     and v_existing.expires_at > v_now then
    raise exception 'subscription_active' using errcode = 'P0001';
  end if;

  insert into public.subscriptions (user_id, expires_at, source, trial_used_at, cancelled)
  values (v_user_id, v_expires_at, 'free_trial', v_now, false)
  on conflict (user_id) do update
    set expires_at    = excluded.expires_at,
        source        = excluded.source,
        trial_used_at = excluded.trial_used_at,
        cancelled     = false;

  return v_expires_at;
end;
$$;


--
-- Name: update_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ai_usage; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_usage (
    user_id uuid NOT NULL,
    date date DEFAULT CURRENT_DATE NOT NULL,
    voice_count integer DEFAULT 0 NOT NULL,
    image_count integer DEFAULT 0 NOT NULL,
    CONSTRAINT ai_usage_image_count_check CHECK ((image_count >= 0)),
    CONSTRAINT ai_usage_voice_count_check CHECK ((voice_count >= 0))
);


--
-- Name: api_rate_limits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_rate_limits (
    user_id uuid NOT NULL,
    endpoint text NOT NULL,
    window_start timestamp with time zone NOT NULL,
    request_count integer DEFAULT 1 NOT NULL
);


--
-- Name: chat_user_context_cache; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chat_user_context_cache (
    user_id uuid NOT NULL,
    cache_name text NOT NULL,
    signature text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: custom_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.custom_categories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    name text NOT NULL,
    type text NOT NULL,
    icon_code integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT custom_categories_type_check CHECK ((type = ANY (ARRAY['income'::text, 'expense'::text])))
);


--
-- Name: promo_code_redemptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.promo_code_redemptions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    promo_code_id uuid NOT NULL,
    user_id uuid NOT NULL,
    redeemed_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: promo_codes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.promo_codes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code text NOT NULL,
    duration_days integer DEFAULT 30 NOT NULL,
    max_uses integer,
    use_count integer DEFAULT 0 NOT NULL,
    valid_until timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: rate_limits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rate_limits (
    user_id uuid NOT NULL,
    endpoint text NOT NULL,
    window_start timestamp with time zone NOT NULL,
    count integer DEFAULT 0 NOT NULL
);


--
-- Name: recurring_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recurring_transactions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    amount numeric(12,2) NOT NULL,
    type text NOT NULL,
    category text NOT NULL,
    description text,
    recurrence_type text NOT NULL,
    next_occurrence date NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    subcategory text,
    CONSTRAINT recurring_transactions_recurrence_type_check CHECK ((recurrence_type = ANY (ARRAY['weekly'::text, 'monthly'::text, 'annual'::text]))),
    CONSTRAINT recurring_transactions_type_check CHECK ((type = ANY (ARRAY['income'::text, 'expense'::text])))
);


--
-- Name: stripe_customers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stripe_customers (
    user_id uuid NOT NULL,
    stripe_customer_id text NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: subcategories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.subcategories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    category text NOT NULL,
    type text NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT subcategories_type_check CHECK ((type = ANY (ARRAY['income'::text, 'expense'::text])))
);


--
-- Name: subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.subscriptions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    store_tx_id text,
    source text DEFAULT 'google_play'::text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    cancelled boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone,
    trial_used_at timestamp with time zone
);


--
-- Name: transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.transactions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    amount numeric(12,2) NOT NULL,
    type text NOT NULL,
    category text NOT NULL,
    description text,
    date date DEFAULT CURRENT_DATE NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    subcategory text,
    recurring_transaction_id uuid,
    currency text DEFAULT 'EUR'::text NOT NULL,
    CONSTRAINT transactions_type_check CHECK ((type = ANY (ARRAY['income'::text, 'expense'::text])))
);


--
-- Name: ai_usage ai_usage_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_usage
    ADD CONSTRAINT ai_usage_pkey PRIMARY KEY (user_id, date);


--
-- Name: api_rate_limits api_rate_limits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_rate_limits
    ADD CONSTRAINT api_rate_limits_pkey PRIMARY KEY (user_id, endpoint, window_start);


--
-- Name: chat_user_context_cache chat_user_context_cache_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_user_context_cache
    ADD CONSTRAINT chat_user_context_cache_pkey PRIMARY KEY (user_id);


--
-- Name: custom_categories custom_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_categories
    ADD CONSTRAINT custom_categories_pkey PRIMARY KEY (id);


--
-- Name: promo_code_redemptions promo_code_redemptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.promo_code_redemptions
    ADD CONSTRAINT promo_code_redemptions_pkey PRIMARY KEY (id);


--
-- Name: promo_code_redemptions promo_code_redemptions_promo_code_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.promo_code_redemptions
    ADD CONSTRAINT promo_code_redemptions_promo_code_id_user_id_key UNIQUE (promo_code_id, user_id);


--
-- Name: promo_codes promo_codes_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.promo_codes
    ADD CONSTRAINT promo_codes_code_key UNIQUE (code);


--
-- Name: promo_codes promo_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.promo_codes
    ADD CONSTRAINT promo_codes_pkey PRIMARY KEY (id);


--
-- Name: rate_limits rate_limits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rate_limits
    ADD CONSTRAINT rate_limits_pkey PRIMARY KEY (user_id, endpoint, window_start);


--
-- Name: recurring_transactions recurring_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recurring_transactions
    ADD CONSTRAINT recurring_transactions_pkey PRIMARY KEY (id);


--
-- Name: stripe_customers stripe_customers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stripe_customers
    ADD CONSTRAINT stripe_customers_pkey PRIMARY KEY (user_id);


--
-- Name: stripe_customers stripe_customers_stripe_customer_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stripe_customers
    ADD CONSTRAINT stripe_customers_stripe_customer_id_key UNIQUE (stripe_customer_id);


--
-- Name: subcategories subcategories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subcategories
    ADD CONSTRAINT subcategories_pkey PRIMARY KEY (id);


--
-- Name: subscriptions subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_pkey PRIMARY KEY (id);


--
-- Name: transactions transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_pkey PRIMARY KEY (id);


--
-- Name: chat_user_context_cache_expires_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX chat_user_context_cache_expires_at_idx ON public.chat_user_context_cache USING btree (expires_at);


--
-- Name: idx_api_rate_limits_window_start; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_api_rate_limits_window_start ON public.api_rate_limits USING btree (window_start);


--
-- Name: idx_cc_user_type_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_cc_user_type_name ON public.custom_categories USING btree (user_id, type, name);


--
-- Name: idx_promo_code_redemptions_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_promo_code_redemptions_user_id ON public.promo_code_redemptions USING btree (user_id);


--
-- Name: idx_recurring_transactions_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_recurring_transactions_user_id ON public.recurring_transactions USING btree (user_id);


--
-- Name: idx_sub_user_cat_type_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_sub_user_cat_type_name ON public.subcategories USING btree (user_id, category, type, name);


--
-- Name: idx_subscriptions_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_subscriptions_user_id ON public.subscriptions USING btree (user_id);


--
-- Name: idx_transactions_recurring_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_transactions_recurring_id ON public.transactions USING btree (recurring_transaction_id) WHERE (recurring_transaction_id IS NOT NULL);


--
-- Name: idx_transactions_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_transactions_user_id ON public.transactions USING btree (user_id);


--
-- Name: rate_limits_window_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rate_limits_window_idx ON public.rate_limits USING btree (window_start);


--
-- Name: subscriptions subscriptions_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER subscriptions_updated_at BEFORE UPDATE ON public.subscriptions FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: ai_usage ai_usage_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_usage
    ADD CONSTRAINT ai_usage_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: api_rate_limits api_rate_limits_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_rate_limits
    ADD CONSTRAINT api_rate_limits_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: chat_user_context_cache chat_user_context_cache_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_user_context_cache
    ADD CONSTRAINT chat_user_context_cache_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: custom_categories custom_categories_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_categories
    ADD CONSTRAINT custom_categories_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: promo_code_redemptions promo_code_redemptions_promo_code_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.promo_code_redemptions
    ADD CONSTRAINT promo_code_redemptions_promo_code_id_fkey FOREIGN KEY (promo_code_id) REFERENCES public.promo_codes(id) ON DELETE CASCADE;


--
-- Name: promo_code_redemptions promo_code_redemptions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.promo_code_redemptions
    ADD CONSTRAINT promo_code_redemptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: rate_limits rate_limits_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rate_limits
    ADD CONSTRAINT rate_limits_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: recurring_transactions recurring_transactions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recurring_transactions
    ADD CONSTRAINT recurring_transactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: stripe_customers stripe_customers_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stripe_customers
    ADD CONSTRAINT stripe_customers_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: subcategories subcategories_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subcategories
    ADD CONSTRAINT subcategories_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: subscriptions subscriptions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: transactions transactions_recurring_transaction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_recurring_transaction_id_fkey FOREIGN KEY (recurring_transaction_id) REFERENCES public.recurring_transactions(id) ON DELETE SET NULL;


--
-- Name: transactions transactions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: promo_codes Allow public read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow public read" ON public.promo_codes FOR SELECT USING (true);


--
-- Name: stripe_customers Service role can manage stripe customers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Service role can manage stripe customers" ON public.stripe_customers USING ((auth.role() = 'service_role'::text));


--
-- Name: transactions Users can delete their own transactions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can delete their own transactions" ON public.transactions FOR DELETE USING ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: transactions Users can insert their own transactions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert their own transactions" ON public.transactions FOR INSERT WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: stripe_customers Users can read own stripe customer; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can read own stripe customer" ON public.stripe_customers FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: transactions Users can update their own transactions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update their own transactions" ON public.transactions FOR UPDATE USING ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: api_rate_limits Users can view their own rate limits; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view their own rate limits" ON public.api_rate_limits FOR SELECT TO authenticated USING ((( SELECT api_rate_limits.user_id) = ( SELECT auth.uid() AS uid)));


--
-- Name: transactions Users can view their own transactions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view their own transactions" ON public.transactions FOR SELECT USING ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: subscriptions Users can view their subscription; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view their subscription" ON public.subscriptions FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: custom_categories Users manage own custom categories; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users manage own custom categories" ON public.custom_categories USING ((( SELECT auth.uid() AS uid) = user_id)) WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: promo_code_redemptions Users manage own redemptions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users manage own redemptions" ON public.promo_code_redemptions USING ((( SELECT auth.uid() AS uid) = user_id)) WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: subcategories Users manage own subcategories; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users manage own subcategories" ON public.subcategories USING ((( SELECT auth.uid() AS uid) = user_id)) WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: subscriptions Users manage own subscription; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users manage own subscription" ON public.subscriptions USING ((( SELECT auth.uid() AS uid) = user_id)) WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: chat_user_context_cache Users manage their own chat cache; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users manage their own chat cache" ON public.chat_user_context_cache USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: ai_usage; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ai_usage ENABLE ROW LEVEL SECURITY;

--
-- Name: api_rate_limits; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.api_rate_limits ENABLE ROW LEVEL SECURITY;

--
-- Name: chat_user_context_cache; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.chat_user_context_cache ENABLE ROW LEVEL SECURITY;

--
-- Name: custom_categories; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.custom_categories ENABLE ROW LEVEL SECURITY;

--
-- Name: promo_code_redemptions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.promo_code_redemptions ENABLE ROW LEVEL SECURITY;

--
-- Name: promo_codes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.promo_codes ENABLE ROW LEVEL SECURITY;

--
-- Name: rate_limits; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.rate_limits ENABLE ROW LEVEL SECURITY;

--
-- Name: recurring_transactions recurring_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY recurring_delete ON public.recurring_transactions FOR DELETE USING ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: recurring_transactions recurring_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY recurring_insert ON public.recurring_transactions FOR INSERT WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: recurring_transactions recurring_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY recurring_select ON public.recurring_transactions FOR SELECT USING ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: recurring_transactions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.recurring_transactions ENABLE ROW LEVEL SECURITY;

--
-- Name: recurring_transactions recurring_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY recurring_update ON public.recurring_transactions FOR UPDATE USING ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: stripe_customers; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.stripe_customers ENABLE ROW LEVEL SECURITY;

--
-- Name: subcategories; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.subcategories ENABLE ROW LEVEL SECURITY;

--
-- Name: subscriptions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

--
-- Name: transactions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

--
-- Name: ai_usage users_read_own_ai_usage; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY users_read_own_ai_usage ON public.ai_usage FOR SELECT USING ((( SELECT auth.uid() AS uid) = user_id));


--
-- PostgreSQL database dump complete
--

\unrestrict LCSXqM1cN6Tua55sdlOvpxIHgOadzFMeYztwOcEvpvGgeG8gUISrUAgZqZzmOU9

