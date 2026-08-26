# Checklist de publicação — Google Play

Este documento separa o que já está preparado no código do que precisa ser concluído manualmente no Play Console.

## Preparado no projeto

- Identificador Android: `com.ramos.kennedy.barberapp`.
- Nome do aplicativo: `BarberKR`.
- Versão: `2.1.0+4003`.
- `compileSdk` e `targetSdk`: API 36.
- Android App Bundle e APK assinados por chave de upload privada.
- Fallback para assinatura debug bloqueado em builds release.
- Minificação R8 e remoção de recursos habilitadas.
- Ícone, permissões, links profundos e Firebase configurados.
- Política de privacidade e processo de exclusão acessíveis dentro do app.

## Gerar os artefatos

```powershell
.\scripts\create_upload_keystore.ps1 # executar somente na primeira vez
.\scripts\build_release.ps1
```

Arquivos:

- `build/app/outputs/bundle/release/app-release.aab` — enviar ao Play Console.
- `build/app/outputs/flutter-apk/app-release.apk` — homologação/instalação direta.

Faça backup seguro de `android/upload-keystore.jks` e `android/key.properties`. Eles não são versionados.

## Cadastro no Play Console

1. Crie o aplicativo com o pacote `com.ramos.kennedy.barberapp`.
2. Ative o **Play App Signing**.
3. Comece pela faixa de **teste interno**.
4. Envie o AAB e corrija qualquer alerta do relatório de pré-lançamento.
5. Aumente sempre o `versionCode` após cada AAB enviado.

## Ficha sugerida

**Nome:** BarberKR

**Descrição curta:**

`Encontre barbearias, agende horários e organize sua rotina em um só app.`

**Descrição completa:**

> O BarberKR conecta clientes e barbearias em uma experiência simples e moderna. Encontre estabelecimentos próximos, consulte serviços e horários, agende atendimentos, converse diretamente com a barbearia e acompanhe suas notificações. Para profissionais, o app oferece painel diário, agenda, histórico, serviços, planos e gestão de disponibilidade.

Categoria sugerida: **Beleza** ou **Estilo de vida**. A classificação final deve refletir a escolha disponível no Console.

## Materiais manuais

- ícone de alta resolução (512 × 512, PNG);
- imagem de destaque (1.024 × 500);
- pelo menos duas capturas de tela de telefone sem dados pessoais;
- e-mail e site de suporte públicos;
- credenciais de teste para a equipe de revisão;
- público-alvo, classificação de conteúdo e declaração de anúncios.

## URLs para a ficha

Após confirmar que o repositório está público:

- Política de privacidade: `https://github.com/KennnedyRamos/agendamento-app/blob/main/docs/PRIVACY_POLICY.md`
- Exclusão de conta: `https://github.com/KennnedyRamos/agendamento-app/blob/main/docs/ACCOUNT_DELETION.md`

Para uma publicação comercial, prefira hospedar esses documentos em páginas permanentes do domínio do produto.

## Rascunho da seção Segurança dos dados

Revise este rascunho no momento do envio, pois a declaração deve refletir o backend efetivamente publicado e os provedores ativos.

| Categoria | Uso esperado |
|---|---|
| Informações pessoais | Nome, e-mail e telefone para conta e atendimento |
| Mensagens | Chat iniciado pelo usuário |
| Fotos | Logo escolhida pela barbearia |
| Atividade no app | Agendamentos, cancelamentos, planos e avaliações |
| Identificadores do dispositivo | Token FCM para notificações |
| Localização | Acessada de forma opcional e efêmera para ordenar proximidade |
| Informações financeiras | Checkout processado pelo Mercado Pago; o app não armazena dados completos do cartão |

Declare criptografia em trânsito, mecanismo de exclusão e práticas dos SDKs de terceiros conforme a configuração final.

## Bloqueios externos antes de produção

- Publicar as Cloud Functions e seus segredos em um projeto Firebase no plano Blaze para habilitar Mercado Pago e push de servidor.
- Configurar OAuth/webhook do Mercado Pago conforme [mercado_pago_setup.md](mercado_pago_setup.md).
- Hospedar e validar as URLs legais.
- Concluir cadastro/verificação da conta Google Play e pagar a taxa aplicável.
- Executar teste interno em aparelhos físicos e revisar acessibilidade, crashes e ANRs.

Referências oficiais:

- [Requisitos de API alvo](https://support.google.com/googleplay/android-developer/answer/11926878)
- [Assinatura de aplicativos](https://developer.android.com/studio/publish/app-signing)
- [Envio de Android App Bundle](https://developer.android.com/studio/publish/upload-bundle)
- [Segurança dos dados](https://support.google.com/googleplay/android-developer/answer/10787469)
- [Exclusão de contas](https://support.google.com/googleplay/android-developer/answer/13327111)
