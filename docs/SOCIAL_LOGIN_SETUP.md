# 外部ログインの接続設定

メールでの登録・ログインは利用できます。外部ログインはまだ各社のクライアント登録が未実施のため、未接続のボタンを利用者に表示しません。

iOSには `ASWebAuthenticationSession` とPKCE（S256）でSupabase Authに接続する処理を実装しています。アクセストークンとリフレッシュトークンはKeychainで管理し、プロバイダーの秘密キーはアプリへ含めません。

## 共通
- Supabase Auth → URL Configuration → Redirect URLsに `positivefinger://auth/callback` を追加する。
- 外部プロバイダーに登録するコールバックは `https://ctyzaihzltcncspujmnb.supabase.co/auth/v1/callback`。
- 各社のクライアントID／秘密キーはSupabaseのプロバイダー設定に直接登録する。Gitやチャットへ貼り付けない。
- 新規登録・既存ユーザーの再ログイン・キャンセル・有効期限切れ・アプリ復帰・メール方式と外部方式のアカウント重複を実機確認する。

## Google
Google CloudでOAuth同意画面とWebクライアントを作成し、上記Supabaseコールバックを登録。SupabaseのGoogleプロバイダーを有効化する。アプリはSupabaseの公開認証設定から有効なGoogleプロバイダーを確認した後、ボタンを表示します。

## Apple
Sign in with Apple用の開発者登録、Services ID、ドメイン／リダイレクトの登録、署名キー等の設定が必要です。現在のPersonal Teamだけで設定済みとは扱いません。SupabaseのAppleプロバイダーを有効化した後、アプリにボタンが表示されます。

## LINE
SupabaseのカスタムOAuth/OIDCプロバイダーとして `custom:line` を設定する方式です。LINE DevelopersのLINE Loginチャンネル、コールバック、プロフィール／メール取得の権限・クレーム対応を確認してください。プロバイダー識別子を `custom:line` とし、接続確認後のみアプリのInfo.plistにBooleanの `PFLineLoginEnabled = YES` を追加します。現在は無効です。

## 参考
- https://supabase.com/docs/guides/auth/social-login/auth-google
- https://supabase.com/docs/guides/auth/social-login/auth-apple
- https://supabase.com/docs/guides/auth/custom-oauth-providers
- https://supabase.com/docs/reference/swift/auth-signinwithoauth
