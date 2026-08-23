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
## 📂 Organização do projeto

A aplicação foi organizada de forma a separar responsabilidades entre modelos, telas, serviços e configurações.

| Diretório / Arquivo | Responsabilidade |
|---|---|
| `models/` | Modelos utilizados pela aplicação |
| `screens/` | Telas e componentes da interface |
| `services/` | Serviços responsáveis pela comunicação com o banco e pelas regras relacionadas aos agendamentos |
| `_colors/` | Definição das cores utilizadas na aplicação |
| `main.dart` | Ponto de entrada da aplicação |

---

## ☁️ Arquitetura de serviços

A aplicação utiliza serviços em nuvem para diferentes responsabilidades:

```text
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

                      
# ✂️ Agendamento App

Aplicação mobile desenvolvida com **Flutter e Dart** para gerenciamento de agendamentos em barbearias.

O projeto utiliza **Firebase** para autenticação e persistência de dados, além do **Supabase Storage** para armazenamento de imagens.

---

## 🚀 Funcionalidades

* 🔐 Cadastro e autenticação de usuários
* 📅 Visualização de calendário
* 🕐 Seleção de horários disponíveis
* 📌 Criação de agendamentos
* ❌ Cancelamento de agendamentos
* 🔄 Gerenciamento da disponibilidade de horários
* ☁️ Integração com Firebase
* 🗄️ Armazenamento de imagens com Supabase Storage
* 📱 Interface desenvolvida em Flutter

---

## 🛠️ Tecnologias utilizadas

| Tecnologia                  | Utilização                          |
| --------------------------- | ----------------------------------- |
| **Flutter**                 | Desenvolvimento da aplicação mobile |
| **Dart**                    | Linguagem de programação            |
| **Firebase Authentication** | Autenticação de usuários            |
| **Cloud Firestore**         | Persistência dos dados              |
| **Supabase Storage**        | Armazenamento de imagens            |
| **Android Studio**          | Ambiente de desenvolvimento         |
| **Git / GitHub**            | Versionamento do projeto            |

---

# 🔧 Instalação e execução

## 📋 Pré-requisitos

Antes de executar o projeto, é necessário possuir:

* Flutter instalado
* Dart
* Android Studio ou ambiente equivalente
* Emulador Android ou dispositivo físico
* Conta/projeto configurado no Firebase
* Projeto configurado no Supabase, caso sejam utilizadas as funcionalidades de armazenamento de imagens

---

## 1. 📥 Clone o repositório

```bash
git clone https://github.com/KennnedyRamos/agendamento-app.git
```

Entre na pasta do projeto:

```bash
cd agendamento-app
```

---

## 2. 📦 Instale as dependências

Execute:

```bash
flutter pub get
```

---

## 3. 🔥 Configure o Firebase

Crie ou utilize um projeto no Firebase e configure a aplicação Flutter.

O projeto utiliza:

* **Firebase Authentication**
* **Firebase Cloud Firestore**

Configure as informações necessárias no projeto Flutter.

O arquivo relacionado à configuração do Firebase é:

```text
lib/firebase_options.dart
```

> ⚠️ **Atenção:** nunca publique credenciais, chaves privadas ou outras informações sensíveis no repositório.

---

## 4. 🗄️ Configure o Supabase Storage

O projeto possui configuração para utilização do **Supabase Storage** para armazenamento de imagens.

### 🪣 Bucket

O bucket utilizado é:

```text
barbershop-images
```

### ⚙️ Configuração

| Configuração          | Valor        |
| --------------------- | ------------ |
| **Public**            | ON           |
| **MIME Type**         | `image/jpeg` |
| **MIME Type**         | `image/png`  |
| **MIME Type**         | `image/webp` |
| **Limite de arquivo** | 2 MB         |

---

### 🔐 Policies do Storage

As policies utilizadas controlam o acesso às pastas de cada usuário.

#### INSERT

```sql
create policy "barbershops insert (own folder)"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'barbershop-images'
  and name like 'barbershops/' || auth.uid() || '/%'
);
```

#### UPDATE

```sql
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
```

#### SELECT

```sql
create policy "barbershops select (bucket)"
on storage.objects for select
using (bucket_id = 'barbershop-images');
```

---

## 🔐 Configuração com Dart Define

Para executar o projeto utilizando as variáveis do Supabase, podem ser utilizadas variáveis de ambiente através do `dart-define`.

### Windows PowerShell

Configure as variáveis:

```powershell
$env:SUPABASE_URL="https://YOUR_PROJECT.supabase.co"
$env:SUPABASE_ANON_KEY="YOUR_ANON_KEY"
```

Execute o projeto:

```powershell
./scripts/run_debug.ps1
```

### 📦 Gerar o build

Para gerar o APK de debug:

```powershell
./scripts/build_debug_apk.ps1
```

> ⚠️ **Atenção:** substitua os valores de exemplo pelas configurações do seu próprio projeto.
>
> Nunca publique chaves privadas ou outras informações sensíveis no GitHub.

---

## 5. ▶️ Execute a aplicação

Depois de configurar todas as dependências:

```bash
flutter run
```

---

# 📱 Como utilizar

## 👤 Cadastro

O usuário pode criar uma conta utilizando:

* E-mail
* Senha

---

## 🔑 Login

Após o cadastro, o usuário pode acessar a aplicação utilizando suas credenciais.

---

## 📅 Agendamento

Para realizar um agendamento:

1. Acesse o calendário.
2. Selecione uma data.
3. Escolha um horário disponível.
4. Confirme o agendamento.

---

## ❌ Cancelamento

O usuário pode cancelar um agendamento existente.

Após o cancelamento, o horário é novamente disponibilizado para novos agendamentos.

---

# 🧪 Testes

Os testes podem ser executados através do comando:

```bash
flutter test
```

---

# 📂 Arquivos ignorados

O projeto utiliza o arquivo `.gitignore` para evitar o versionamento de arquivos temporários e arquivos gerados pelo ambiente de desenvolvimento.

Entre eles:

```gitignore
*.class
*.log
*.pyc

.dart_tool/
/.pub-cache/
/build/

.idea/
.vscode/
```

---

# 📚 Aprendizados

O desenvolvimento deste projeto proporcionou experiência prática em diferentes áreas do desenvolvimento mobile, incluindo:

* Desenvolvimento de aplicações com Flutter
* Programação em Dart
* Autenticação de usuários
* Integração com Firebase
* Persistência de dados utilizando Firestore
* Integração com serviços externos
* Gerenciamento de disponibilidade de horários
* Organização de código
* Separação entre telas, modelos e serviços
* Configuração de armazenamento em nuvem
* Utilização de variáveis de ambiente
* Execução e geração de builds Flutter

---

# 🚧 Possíveis evoluções

Algumas funcionalidades podem ser adicionadas ou aprimoradas futuramente:

* 🔔 Notificações de confirmação de agendamento
* ⏰ Lembretes automáticos
* 📊 Painel administrativo
* 🗓️ Gerenciamento de horários pelo estabelecimento
* 📜 Histórico completo de agendamentos
* 💈 Diferentes tipos de serviços
* 💳 Integração com pagamentos
* 🎨 Melhorias na experiência do usuário

---

# 🤝 Contribuição

Contribuições são bem-vindas.

Para contribuir com o projeto:

### 1. Faça um fork do projeto

### 2. Crie uma branch para sua feature

```bash
git checkout -b feature/minha-feature
```

### 3. Faça suas alterações

Implemente e teste as modificações desejadas.

### 4. Realize o commit

```bash
git commit -m "Adiciona nova funcionalidade"
```

### 5. Envie a branch

```bash
git push origin feature/minha-feature
```

### 6. Abra um Pull Request

Descreva as alterações realizadas e envie o Pull Request para análise.

---

# 📄 Licença

Este projeto está licenciado sob a **Licença MIT**.

Consulte o arquivo [`LICENSE`](LICENSE) para mais informações.

---

# 👨‍💻 Desenvolvedor

## Kennedy Ramos

**Desenvolvedor Full Stack** com foco em **Python e Flutter**.

Tenho interesse em desenvolvimento de:

* 🌐 Aplicações Full Stack
* ⚙️ APIs e Backend com Python
* 📱 Aplicações Mobile com Flutter
* ☁️ Integrações com serviços em nuvem

---

# 🔗 Links

* **GitHub:** [KennnedyRamos](https://github.com/KennnedyRamos)
* **LinkedIn:** [Kennedy Ramos](https://www.linkedin.com/in/kennedy-silva-ramos-566b00150/)
* **Portfólio:** [Meu Portfólio](https://kennnedyramos.github.io/meu-postifolio-web/)

---

# ⭐ Apoie o projeto

Se este projeto foi útil ou interessante, considere deixar uma **⭐ estrela no repositório**.

---

<div align="center">

### Feito com Flutter, Dart e dedicação por Kennedy Ramos. 🚀

</div>

---

## 🎯 Objetivo deste README

Este README foi estruturado para apresentar o projeto de forma clara para diferentes públicos:

### 👔 Recrutadores não técnicos

Permite entender rapidamente:

* O que é o projeto
* Qual problema ele resolve
* Quais tecnologias foram utilizadas
* Quais funcionalidades foram desenvolvidas

### 💻 Recrutadores técnicos

Evidencia conhecimentos em:

* Flutter
* Dart
* Firebase
* Firestore
* Supabase
* Autenticação
* Integração com serviços em nuvem
* Gerenciamento de estado e regras de negócio
* Organização e separação de responsabilidades

### 👨‍💻 Desenvolvedores

Fornece informações suficientes para:

* Clonar o projeto
* Configurar as dependências
* Configurar Firebase
* Configurar Supabase
* Executar a aplicação
* Executar os testes
* Gerar o build

---

## 🚀 Posicionamento profissional

O README foi estruturado para reforçar uma apresentação profissional do projeto e criar um caminho claro para quem deseja conhecer mais sobre o desenvolvedor:

**GitHub → LinkedIn → Portfólio**

O objetivo é apresentar primeiro a capacidade técnica demonstrada no projeto e, posteriormente, direcionar o visitante para os demais canais profissionais.
