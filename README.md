# 📅 App de Agendamento — Flutter, Firebase & Supabase

Aplicativo de agendamento desenvolvido em **Flutter**, com autenticação de usuários, gerenciamento de horários e integração com serviços em nuvem.

O projeto foi desenvolvido como uma aplicação completa, contemplando desde o fluxo de cadastro e autenticação até o gerenciamento de disponibilidade dos horários, cancelamento de agendamentos e armazenamento de dados.

> 🚀 Projeto desenvolvido por Kennedy Ramos como parte do meu portfólio de desenvolvimento mobile.

---

## 📌 Sobre o projeto

O **App de Agendamento** foi desenvolvido para solucionar um problema comum em sistemas de agendamento: permitir que usuários consultem horários disponíveis, realizem reservas e liberem automaticamente os horários quando um agendamento é cancelado.

A aplicação possui:

- Cadastro e autenticação de usuários;
- Recuperação de senha;
- Calendário para consulta de disponibilidade;
- Criação de agendamentos;
- Bloqueio de horários já reservados;
- Cancelamento de agendamentos;
- Liberação dos horários após cancelamento;
- Persistência dos dados em serviços de nuvem.

O projeto também utiliza **Supabase Storage** para armazenamento de imagens relacionadas às barbearias.

---

# 🎯 Objetivos

O desenvolvimento teve como principais objetivos:

- Criar uma aplicação mobile multiplataforma utilizando Flutter;
- Implementar um fluxo completo de autenticação;
- Trabalhar com persistência de dados em nuvem;
- Criar uma lógica de controle de disponibilidade de horários;
- Organizar o código utilizando separação entre telas, modelos e serviços;
- Trabalhar com integração entre diferentes serviços de backend/cloud;
- Desenvolver uma aplicação próxima de um cenário real de utilização.

---

# 🚀 Principais funcionalidades

## 👤 Autenticação

A aplicação utiliza **Firebase Authentication** para gerenciamento dos usuários.

Funcionalidades disponíveis:

- Cadastro de usuários;
- Login;
- Redefinição de senha;
- Validação de senha;
- Opção de "Lembrar-me";
- Controle para evitar múltiplas contas.

---

## 📅 Sistema de agendamento

O usuário pode visualizar os horários disponíveis através de um calendário.

### Fluxo de agendamento

1. O usuário acessa o calendário;
2. Seleciona uma data;
3. Consulta os horários disponíveis;
4. Seleciona um horário;
5. Confirma o agendamento;
6. O horário passa a ficar indisponível para outros usuários.

---

## 🔄 Cancelamento de agendamento

Quando um usuário cancela um agendamento:

- O agendamento é removido;
- O horário é liberado;
- O horário volta a ficar disponível para outros usuários.

Essa lógica permite manter o controle de disponibilidade dos horários de forma dinâmica.

---

# 🧠 Principais desafios do projeto

Durante o desenvolvimento, alguns dos principais desafios envolveram a implementação da lógica responsável pelo controle de disponibilidade dos horários.

O sistema precisava garantir que:

- Horários já utilizados não fossem disponibilizados novamente para outros usuários;
- Um cancelamento liberasse corretamente o horário;
- Os dados dos agendamentos permanecessem sincronizados com o banco;
- O fluxo de autenticação funcionasse de forma integrada à aplicação;
- A estrutura do projeto permanecesse organizada conforme novas funcionalidades fossem adicionadas.

Outro ponto importante foi trabalhar com diferentes serviços de infraestrutura, utilizando **Firebase** para autenticação e banco de dados e **Supabase Storage** para armazenamento de imagens.

---

# 🛠️ Tecnologias utilizadas

## Flutter

Framework utilizado para desenvolvimento da aplicação mobile multiplataforma.

## Dart

Linguagem utilizada no desenvolvimento da aplicação.

## Firebase Authentication

Utilizado para:

- Cadastro;
- Login;
- Recuperação de senha;
- Gerenciamento da autenticação dos usuários.

## Firebase Firestore

Banco de dados utilizado para armazenamento das informações da aplicação.

## Supabase Storage

Utilizado para armazenamento de imagens relacionadas às barbearias.

## TableCalendar

Plugin utilizado para construção da interface de calendário e interação com datas e horários.

---

# 🏗️ Estrutura do projeto

A aplicação foi organizada buscando separar responsabilidades entre modelos, telas e serviços.

```text
project/
│
├── lib/
│   ├── _colors/
│   │   └── my_colors.dart
│   │
│   ├── app/
│   │   ├── models/
│   │   │   └── cadastro_cliente_models.dart
│   │   │
│   │   ├── screens/
│   │   │   ├── Widget/
│   │   │   │   └── appointments_list_tile.dart
│   │   │   │
│   │   │   ├── events_page.dart
│   │   │   ├── home_page.dart
│   │   │   ├── login_page_cliente.dart
│   │   │   ├── profile_page.dart
│   │   │   ├── register_page.dart
│   │   │   ├── reset_password_page.dart
│   │   │   └── welcome_page.dart
│   │   │
│   │   ├── services/
│   │   │   ├── appointment_services.dart
│   │   │   └── firestone_service.dart
│   │   │
│   │   └── app_widget.dart
│   │
│   ├── firebase_options.dart
│   └── main.dart
│
├── android/
├── ios/
└── pubspec.yaml
```
Organização
models/ → modelos utilizados pela aplicação;
screens/ → telas e componentes da interface;
services/ → serviços responsáveis pela comunicação e regras relacionadas aos agendamentos e banco;
_colors/ → definição de cores utilizadas na aplicação;
main.dart → ponto de entrada da aplicação.
☁️ Arquitetura de serviços

A aplicação utiliza serviços em nuvem para diferentes responsabilidades:

                ┌─────────────────────┐
                │    Flutter / Dart   │
                │     Aplicação       │
                └──────────┬──────────┘
                           │
              ┌────────────┴────────────┐
              │                         │
              ▼                         ▼
     ┌─────────────────┐       ┌─────────────────┐
     │ Firebase Auth   │       │ Firebase        │
     │                 │       │ Firestore       │
     │ Autenticação    │       │ Dados           │
     └─────────────────┘       └─────────────────┘
                                     
                           │
                           ▼
                  ┌─────────────────┐
                  │ Supabase        │
                  │ Storage         │
                  │                 │
                  │ Imagens         │
                  └─────────────────┘
🔧 Instalação e execução
Pré-requisitos

Antes de executar o projeto, é necessário possuir:

Flutter instalado;
Dart;
Android Studio ou ambiente equivalente;
Emulador Android ou dispositivo físico;
Conta/projeto configurado no Firebase;
Configuração do Supabase caso sejam utilizadas as funcionalidades de armazenamento de imagens.
1. Clone o repositório
git clone https://github.com/KennnedyRamos/agendamento-app.git

Entre na pasta:

cd agendamento-app
2. Instale as dependências

Execute:

flutter pub get
🔥 3. Configure o Firebase

Crie ou utilize um projeto no Firebase e configure a aplicação Flutter.

O projeto utiliza:

Firebase Authentication;
Firebase Firestore.

Configure as informações necessárias no projeto Flutter.

O arquivo relacionado à configuração do Firebase é:

lib/firebase_options.dart

⚠️ Nunca publique credenciais, chaves privadas ou informações sensíveis no repositório.

🗄️ 4. Configure o Supabase Storage

O projeto possui configuração para utilização do Supabase Storage para armazenamento de imagens.

Bucket

O bucket utilizado é:

barbershop-images

Configuração documentada:

Public: ON
MIME types permitidos:
image/jpeg
image/png
image/webp
Limite de arquivo: 2 MB
Policies do Storage

As policies utilizadas para controle das pastas por usuário são:

-- INSERT
create policy "barbershops insert (own folder)"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'barbershop-images'
  and name like 'barbershops/' || auth.uid() || '/%'
);

-- UPDATE
create policy "barbershops update (own folder)"
on storage.objects for update to authenticated
using (
  bucket_id = 'barbershop-images'
  and name like 'barbershops/' || auth.uid() || '/%'
)
with check (
  bucket_id = 'barbershop-images'
  and name like 'barbershops/' || auth.uid() || '/%'
);

-- SELECT
create policy "barbershops select (bucket)"
on storage.objects for select
using (bucket_id = 'barbershop-images');
🔐 Configuração com Dart Define

Para executar o projeto utilizando as variáveis do Supabase, podem ser utilizadas variáveis de ambiente através de dart-define.

PowerShell
$env:SUPABASE_URL="https://YOUR_PROJECT.supabase.co"
$env:SUPABASE_ANON_KEY="YOUR_ANON_KEY"

./scripts/run_debug.ps1

Para gerar o build:

./scripts/build_debug_apk.ps1

⚠️ Substitua os valores de exemplo pelas configurações do seu próprio projeto. Não publique chaves privadas no GitHub.

▶️ 5. Execute a aplicação

Depois de configurar as dependências:

flutter run
📱 Como utilizar
Cadastro

O usuário cria uma conta utilizando e-mail e senha.

Login

Após o cadastro, o usuário pode acessar a aplicação utilizando suas credenciais.

Agendamento
Acesse o calendário;
Selecione uma data;
Escolha um horário disponível;
Confirme o agendamento.
Cancelamento

O usuário pode cancelar um agendamento existente.

Após o cancelamento, o horário é novamente disponibilizado.

🧪 Testes

Os testes podem ser executados através do comando:

flutter test
📂 Arquivos ignorados

O projeto utiliza .gitignore para evitar o versionamento de arquivos temporários e arquivos gerados pelo ambiente de desenvolvimento.

Entre eles:

*.class
*.log
*.pyc

.dart_tool/
/.pub-cache/
/build/

.idea/
.vscode/
📚 Aprendizados

O desenvolvimento deste projeto proporcionou experiência prática em diferentes áreas do desenvolvimento mobile, incluindo:

Desenvolvimento de aplicações com Flutter;
Programação em Dart;
Autenticação de usuários;
Integração com Firebase;
Persistência de dados utilizando Firestore;
Integração com serviços externos;
Gerenciamento de disponibilidade de horários;
Organização de código;
Separação entre telas, modelos e serviços;
Configuração de armazenamento em nuvem;
Utilização de variáveis de ambiente;
Execução e geração de builds Flutter.
🚧 Possíveis evoluções

Algumas funcionalidades podem ser adicionadas ou aprimoradas futuramente, como:

Notificações de confirmação de agendamento;
Lembretes automáticos;
Painel administrativo;
Gerenciamento de horários pelo estabelecimento;
Histórico completo de agendamentos;
Diferentes tipos de serviços;
Integração com pagamentos;
Melhorias na experiência do usuário.
🤝 Contribuição

Contribuições são bem-vindas.

Para contribuir:

Faça um fork do projeto;
Crie uma branch para sua feature:
git checkout -b feature/minha-feature
Faça suas alterações;
Realize o commit:
git commit -m "Adiciona nova funcionalidade"
Envie a branch:
git push origin feature/minha-feature
Abra um Pull Request.
📄 Licença

Este projeto está licenciado sob a licença MIT.

Consulte o arquivo LICENSE para mais informações.

👨‍💻 Desenvolvedor

Kennedy Ramos

Desenvolvedor Full Stack com foco em Python e Flutter.

Tenho interesse em desenvolvimento de:

Aplicações Full Stack;
APIs e Backend com Python;
Aplicações Mobile com Flutter;
Integrações com serviços em nuvem.
🔗 Links
GitHub: https://github.com/KennnedyRamos
LinkedIn: https://www.linkedin.com/in/kennedy-silva-ramos-566b00150/
Portfólio: https://kennnedyramos.github.io/meu-postifolio-web/

⭐ Se este projeto foi útil ou interessante, considere deixar uma estrela no repositório.

Feito com Flutter, Dart e dedicação por Kennedy Ramos.


### Uma mudança importante em relação ao seu README atual

Eu **retirei os `[svg]`** que aparecem no texto que você me enviou. Eles são elementos gerados/capturados pela interface do GitHub e **não devem estar no Markdown real**.

Também não colocaria o Instagram nesse README. Para o objetivo que estamos construindo, queremos que o recrutador tenha um caminho muito claro:

**GitHub → LinkedIn → Portfólio**

e não dispersar a atenção para redes pessoais.

### E o mais importante

Esse README agora vende o projeto em três níveis:

**1. Recrutador não técnico:** entende rapidamente o que você construiu.

**2. Recrutador técnico:** vê Flutter, Dart, Firebase, Firestore, Supabase, autenticação, arquitetura e lógica de negócio.

**3. Desenvolvedor:** consegue entender a estrutura e executar o projeto.

Isso está muito mais alinhado ao posicionamento que estamos construindo no LinkedIn.
