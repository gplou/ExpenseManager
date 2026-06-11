// Legal content for Expense Manager by GPM.
// These constants are used by the LegalScreen widget via the app router.
// Last updated: 2026-03-26.

const String privacyPolicyContentEn = '''
Privacy Policy

Last updated: March 26, 2026

GPM ("we", "us", or "our") operates the Expense Manager mobile application (the "App"). This Privacy Policy explains how we collect, use, and protect your personal information when you use our App.

By using Expense Manager, you agree to the collection and use of information in accordance with this policy.


1. Information We Collect

1.1 Account Information
When you create an account, we collect:
- Your name and email address (provided via Google Sign-In or Apple Sign-In).

1.2 Financial Data
To provide expense tracking functionality, we store:
- Transactions you create (amounts, descriptions, categories, dates).
- Custom categories you define.
- Recurring transaction rules you configure.

1.3 Subscription Information
If you subscribe to Expense Manager PRO, we store:
- Purchase history and subscription status.
- Payment information is processed and stored exclusively by Apple (App Store) or Google (Google Play). We do not have access to your credit card or payment method details.

1.4 Media and Voice Data
When you use AI-powered transaction entry, we may temporarily process:
- Photos of receipts you capture or select from your gallery.
- Audio recordings for voice-based transaction entry.

This media is sent to our server-side functions for parsing only and is not stored permanently. It is discarded after the transaction data has been extracted.

1.5 Local Preferences
We store your app preferences (such as theme, language, and display settings) locally on your device using SharedPreferences. This data never leaves your device.


2. How We Use Your Information

We use your information to:
- Provide, maintain, and improve the App's core expense tracking features.
- Authenticate your identity and secure your account.
- Process AI-assisted transaction entry (voice and image parsing) via Supabase Edge Functions powered by Claude AI.
- Manage your PRO subscription status.
- Provide the AI chat assistant feature for financial insights based on your transaction data.


3. Data Storage and Security

Your data is stored securely using Supabase, a hosted backend platform. Supabase implements industry-standard security measures including:
- Encryption in transit (TLS/SSL) and at rest.
- Row-level security policies to ensure you can only access your own data.
- Secure authentication via OAuth providers (Google, Apple).

We take reasonable measures to protect your personal information, but no method of electronic storage or transmission is 100% secure.


4. Third-Party Services

We use the following third-party services:

- Supabase: Backend database, authentication, and serverless functions. See: https://supabase.com/privacy
- Google Sign-In: Authentication provider. See: https://policies.google.com/privacy
- Apple Sign-In: Authentication provider. See: https://www.apple.com/legal/privacy/
- Claude AI (Anthropic): AI processing for voice/image transaction parsing and chat, accessed via Supabase Edge Functions. See: https://www.anthropic.com/privacy
- Google Play Billing / Apple In-App Purchase: Subscription payment processing.
- Google AdMob: Advertising in the free tier. See: https://policies.google.com/privacy

These services may collect information as described in their respective privacy policies.


5. Tracking and Analytics

We do not track you across other companies' apps or websites. We do not sell, rent, or share your personal data with third parties for their marketing purposes.


6. Data Retention

We retain your account and transaction data for as long as your account is active. If you delete your account, we will delete your personal data from our servers within 30 days, except where retention is required by law.


7. Your Rights

Depending on your jurisdiction, you may have the right to:
- Access the personal data we hold about you.
- Request correction of inaccurate data.
- Request deletion of your data.
- Export your data in a portable format.

To exercise any of these rights, contact us at the email address provided below.


8. Children's Privacy

Expense Manager is not directed at children under the age of 13. We do not knowingly collect personal information from children under 13. If you believe we have collected data from a child, please contact us so we can delete it promptly.


9. International Users

The App is available in Spanish, English, French, and German. Your data may be processed and stored in servers located outside your country of residence. By using the App, you consent to such transfer and processing.


10. Changes to This Policy

We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new policy within the App and updating the "Last updated" date above.


11. Contact Us

If you have any questions about this Privacy Policy, please contact us at:

GPM
Email: support@gpm-apps.com
''';

const String termsOfServiceContentEn = '''
Terms of Service

Last updated: March 26, 2026

Please read these Terms of Service ("Terms") carefully before using the Expense Manager mobile application ("App") operated by GPM ("we", "us", or "our").

By downloading, installing, or using the App, you agree to be bound by these Terms.


1. Acceptance of Terms

By accessing or using Expense Manager, you agree to these Terms and our Privacy Policy. If you do not agree, you must not use the App.


2. Description of Service

Expense Manager is a personal finance tracking application that allows you to:
- Record and categorize income and expense transactions.
- View charts and summaries of your financial activity.
- Set up recurring transactions.
- Use AI-assisted transaction entry via voice or photo.
- Chat with an AI assistant about your finances.
- Access premium features through a PRO subscription.


3. Account Registration

To use the App, you must create an account using Google Sign-In or Apple Sign-In. You are responsible for:
- Maintaining the security of your account credentials.
- All activity that occurs under your account.
- Providing accurate and complete information.

You must be at least 13 years old to create an account and use the App.


4. PRO Subscription

4.1 Expense Manager offers a PRO subscription ("PRO") that provides additional features such as AI-powered voice and image transaction entry, AI chat, and an ad-free experience.

4.2 PRO subscriptions are billed through the Apple App Store or Google Play Store. Payment terms, renewal, and cancellation are governed by the respective store's policies.

4.3 Prices may vary by region and are displayed in your local currency at the time of purchase. We reserve the right to change subscription pricing with reasonable notice.

4.4 Refunds are handled in accordance with the policies of the Apple App Store or Google Play Store.


5. User Content

5.1 You retain ownership of all data you enter into the App (transactions, categories, notes, etc.).

5.2 By using AI features (voice, image, or chat), you grant us a limited, temporary license to process your submitted content (audio, photos, text) solely for the purpose of providing the requested AI functionality. This content is not stored after processing is complete.

5.3 You agree not to use the App to store or transmit any content that is illegal, harmful, or violates the rights of others.


6. Acceptable Use

You agree not to:
- Use the App for any unlawful purpose.
- Attempt to gain unauthorized access to our systems or other users' accounts.
- Reverse-engineer, decompile, or disassemble the App.
- Interfere with or disrupt the App's functionality.
- Use automated tools to access the App beyond normal usage patterns.
- Circumvent any rate limits, access controls, or security features.


7. AI Features Disclaimer

7.1 The AI-powered features (voice parsing, image parsing, and chat) are provided for convenience and informational purposes only.

7.2 AI-generated transaction data should be reviewed and verified by you before saving. We are not responsible for inaccuracies in AI-parsed transactions.

7.3 The AI chat assistant provides general observations about your financial data. It does not constitute financial, tax, legal, or investment advice. You should consult qualified professionals for such matters.


8. Intellectual Property

The App, including its design, code, graphics, and branding, is owned by GPM and is protected by intellectual property laws. You are granted a limited, non-exclusive, non-transferable license to use the App for personal, non-commercial purposes.


9. Disclaimer of Warranties

THE APP IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED. WE DO NOT WARRANT THAT THE APP WILL BE UNINTERRUPTED, ERROR-FREE, OR FREE OF HARMFUL COMPONENTS.

WE MAKE NO WARRANTIES REGARDING THE ACCURACY, RELIABILITY, OR COMPLETENESS OF ANY DATA, TRANSACTION RECORDS, OR AI-GENERATED CONTENT.


10. Limitation of Liability

TO THE MAXIMUM EXTENT PERMITTED BY LAW, GPM SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES ARISING FROM YOUR USE OF THE APP. OUR TOTAL LIABILITY SHALL NOT EXCEED THE AMOUNT YOU HAVE PAID FOR THE APP OR PRO SUBSCRIPTION IN THE TWELVE (12) MONTHS PRECEDING THE CLAIM.

THIS INCLUDES, WITHOUT LIMITATION, ANY LOSS OR INACCURACY OF FINANCIAL DATA, MISSED TRANSACTIONS, OR RELIANCE ON AI-GENERATED CONTENT.


11. Indemnification

You agree to indemnify and hold harmless GPM from any claims, damages, or expenses arising from your use of the App or violation of these Terms.


12. Termination

We may suspend or terminate your access to the App at any time for violation of these Terms or for any other reason at our discretion. Upon termination, your right to use the App ceases immediately. You may request deletion of your data in accordance with our Privacy Policy.


13. Changes to Terms

We reserve the right to modify these Terms at any time. We will notify you of material changes by posting the updated Terms within the App. Your continued use of the App after changes constitutes acceptance of the revised Terms.


14. Governing Law

These Terms shall be governed by and construed in accordance with the laws of the jurisdiction in which GPM is established, without regard to conflict of law provisions.


15. Severability

If any provision of these Terms is found to be unenforceable, the remaining provisions shall continue in full force and effect.


16. Contact Us

If you have any questions about these Terms, please contact us at:

GPM
Email: support@gpm-apps.com
''';
