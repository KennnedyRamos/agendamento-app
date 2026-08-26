# Política de segurança

## Versões suportadas

O desenvolvimento ativo acontece na branch `main`. Correções de segurança são aplicadas na versão mais recente do aplicativo.

## Relatando uma vulnerabilidade

Não publique credenciais, dados pessoais ou detalhes exploráveis em uma issue pública. Envie o relato para **kennedy_ramos9@icloud.com** com o assunto `Segurança — BarberKR` e inclua:

- descrição do comportamento;
- passos mínimos para reprodução;
- impacto observado ou possível;
- versão/commit afetado;
- sugestão de correção, se houver.

O recebimento será confirmado assim que possível. O problema será validado antes da divulgação e os detalhes devem permanecer privados durante a correção.

## Escopo sensível

- regras do Cloud Firestore e Firebase Storage;
- autenticação e tokens FCM;
- concorrência de horários;
- conversas entre cliente e barbearia;
- OAuth, webhooks e intenções de pagamento;
- assinatura e artefatos de release.

Keystores, `key.properties`, `google-services.json` e segredos de integrações não devem ser enviados ao repositório.
