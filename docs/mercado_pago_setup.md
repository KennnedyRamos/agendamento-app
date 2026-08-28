# Configuração do Mercado Pago Marketplace

O aplicativo usa o **Checkout Pro com Split 1:1**. Cada barbearia autoriza a
plataforma via OAuth e recebe os pagamentos diretamente em sua própria conta
Mercado Pago. Os tokens nunca são enviados ao Flutter: ficam criptografados no
Firestore e só podem ser lidos pelas Firebase Functions.

O checkout aceita somente **Pix** e **saldo da conta Mercado Pago**. Cartões,
boleto e outros meios ficam excluídos da preferência. O pagamento em
**Dinheiro — pagar no local** é criado diretamente no aplicativo e continua
disponível mesmo quando a barbearia ainda não conectou o Mercado Pago.

## 1. Criar a aplicação no Mercado Pago

No painel [Suas integrações](https://www.mercadopago.com.br/developers/panel/app),
crie uma aplicação com estas opções:

- Pagamentos online;
- Checkout Pro;
- Modelo Marketplace;
- OAuth com PKCE habilitado.

Cadastre exatamente esta URL de redirecionamento:

```text
https://us-central1-barber-app-e2a38.cloudfunctions.net/mercadoPagoOAuthCallback
```

Configure o evento de webhook **Pagamentos** com esta URL:

```text
https://us-central1-barber-app-e2a38.cloudfunctions.net/mercadoPagoWebhook
```

Guarde o `App ID`, a `Client Secret` e a assinatura secreta do webhook.

## 2. Configurar os segredos das Functions

No estado atual do projeto, a API Cloud Functions ainda está desativada. Antes
dos comandos abaixo, habilite o plano Blaze e a
[Cloud Functions API](https://console.cloud.google.com/apis/library/cloudfunctions.googleapis.com?project=barber-app-e2a38).
O plano exige uma forma de faturamento, mas possui cotas gratuitas; configure
alertas de orçamento no Google Cloud para evitar cobranças inesperadas.

Gere uma chave de criptografia de 32 bytes no PowerShell:

```powershell
$keyBytes = New-Object byte[] 32
$keyGenerator = [Security.Cryptography.RandomNumberGenerator]::Create()
$keyGenerator.GetBytes($keyBytes)
[Convert]::ToBase64String($keyBytes)
$keyGenerator.Dispose()
```

Copie o valor gerado e configure os segredos. A CLI solicitará cada valor sem
gravá-lo no repositório:

```powershell
firebase functions:secrets:set MP_CLIENT_ID
firebase functions:secrets:set MP_CLIENT_SECRET
firebase functions:secrets:set MP_REDIRECT_URI
firebase functions:secrets:set MP_WEBHOOK_URL
firebase functions:secrets:set MP_WEBHOOK_SECRET
firebase functions:secrets:set MP_TOKEN_ENCRYPTION_KEY
firebase functions:secrets:set MP_MARKETPLACE_FEE_PERCENT
firebase functions:secrets:set MP_USE_SANDBOX
```

Valores recomendados para começar:

```text
MP_REDIRECT_URI=https://us-central1-barber-app-e2a38.cloudfunctions.net/mercadoPagoOAuthCallback
MP_WEBHOOK_URL=https://us-central1-barber-app-e2a38.cloudfunctions.net/mercadoPagoWebhook
MP_MARKETPLACE_FEE_PERCENT=3
MP_USE_SANDBOX=true
```

O BarberKR concede 30 dias com comissão de plataforma de 0%, contados da
primeira conexão da barbearia com o Mercado Pago. Depois desse período, o valor
configurado em `MP_MARKETPLACE_FEE_PERCENT` é aplicado automaticamente; `3`
representa 3% do valor da venda. Reconectar a conta não reinicia a promoção. A
taxa do Mercado Pago é descontada separadamente do vendedor.

## 3. Implantar

```powershell
cd C:\dev\agendamento-app
firebase login
firebase deploy --only functions,firestore
```

As Functions utilizam Node.js 20. A implantação exige que o projeto Firebase
esteja no plano Blaze, embora seja possível permanecer dentro das cotas sem
custo conforme o uso.

## 4. Testar

1. Mantenha `MP_USE_SANDBOX=true`.
2. Entre no app com uma conta de barbeiro.
3. Abra **Barbearia** e toque em **Conectar conta**.
4. Autorize uma conta de teste do Mercado Pago e cadastre nela uma chave Pix.
5. Entre como cliente, escolha serviço, data e horário.
6. Toque em **Pagar com Pix ou Mercado Pago** e use o ambiente de teste oficial.
7. Confirme no Firestore que o `payment_intent` ficou com status `paid` e que o
   agendamento correspondente foi criado.
8. Entre novamente como barbeiro e confira o período na aba **Financeiro**.

Antes de produção, troque `MP_USE_SANDBOX` para `false`, configure as
credenciais de produção e execute novamente o deploy das Functions.

## Fluxo implementado

```text
Barbearia conecta conta -> OAuth Mercado Pago -> token criptografado
Cliente escolhe horário -> slot reservado por 30 min -> Checkout Pro
Webhook assinado -> pagamento consultado na API -> agendamento confirmado
Painel financeiro -> receitas e taxas do backend -> saldo gerenciado no Mercado Pago
```

Referências oficiais:

- [Split de pagamentos 1:1](https://www.mercadopago.com.br/developers/pt/docs/split-payments/split-1-1/integration-configuration/integrate-marketplace)
- [OAuth](https://www.mercadopago.com.br/developers/pt/docs/security/oauth/creation)
- [Checkout Pro para Flutter](https://www.mercadopago.com.br/developers/pt/docs/checkout-pro/mobile-integration/flutter)
- [Configuração dos meios de pagamento](https://www.mercadopago.com.br/developers/pt/docs/checkout-pro/additional-settings/payment-methods)
- [Validação de webhooks](https://www.mercadopago.com.br/developers/pt/docs/split-payments/additional-content/your-integrations/notifications/webhooks)
