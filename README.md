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
