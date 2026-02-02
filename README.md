
# App de Agendamento - Flutter & Firebase

Este projeto é um aplicativo de agendamento desenvolvido em Flutter, com autenticação e integração de banco de dados com Firebase. Ele permite aos usuários agendar horários e, caso o agendamento seja cancelado, o horário volta a estar disponível.

## 🚀 Funcionalidades

- Autenticação de usuários com Firebase (login, cadastro, redefinição de senha)
- Tela de calendário para selecionar e agendar horários
- Bloqueio de horários agendados para outros usuários
- Cancelamento de agendamento com liberação do horário
- Integração com Firebase para armazenamento de dados

## 🛠️ Tecnologias Utilizadas

- **Flutter**: Framework para o desenvolvimento multiplataforma.
- **Firebase Authentication**: Para autenticação de usuários.
- **Firebase Firestore**: Banco de dados em nuvem.
- **TableCalendar**: Plugin para exibição e interação com o calendário.

## 📱 Funcionalidades de Agendamento

- O usuário pode selecionar um horário disponível no calendário para agendar.
- Após o agendamento, o horário fica indisponível para outros usuários.
- Caso o usuário cancele o agendamento, o horário volta a ficar disponível para todos.

## 🔐 Autenticação de Usuários

O sistema de autenticação é integrado com Firebase Authentication, permitindo que os usuários façam login, cadastro e redefinam suas senhas. Além disso:

- **Validação de senha**: Exige critérios de segurança para senhas.
- **Opção de "Lembrar-me"**: Usuários podem optar por permanecer logados.
- **Prevenção de múltiplas contas**: Cada usuário só pode ter uma única conta registrada.

## 🚧 Estrutura do Projeto

```bash
project/
│
├── lib/
│   ├── _colors/
│   │   └── my_colors.dart
│   ├── app/
│   │   ├── models/ 
│   │   │     └── cadastro_cliente_models.dart
│   │   ├── screens/
│   │   │     ├── Widget/
│   │   │     │     └── appointments_list_tile.dart
│   │   │     ├── events_page.dart
│   │   │     ├── home_page.dart
│   │   │     ├── login_page_cliente.dart
│   │   │     ├── profile_page.dart
│   │   │     ├── register_page.dart
│   │   │     ├── reset_password_page.dart
│   │   │     └── welcome_page.dart
│   │   ├── services/
│   │   │     ├── appointment_services.dart
│   │   │     └── firestone_service.dart
│   │   └── app_widget.dart
│   ├── firebase_options.dart
│   └── main.dart
├── android/
├── ios/
└── pubspec.yaml
````
## 🔧 Instalação e Execução

### Clone o repositório:

```bash
git clone https://github.com/KennnedyRamos/agendamento-app
````
### Instale as dependências:

```bash
flutter pub get
````
### Configure o Firebase:

Siga as instruções no [Firebase Console](https://firebase.google.com/) para adicionar o projeto Flutter ao Firebase. Configure as opções no arquivo `firebase_options.dart`.

### Execute o app:

```bash
flutter run
````
## 📚 Como Usar

- **Cadastro**: O usuário deve criar uma conta utilizando seu e-mail e senha.
- **Login**: Acesse o aplicativo com as credenciais registradas.
- **Agendamento**: Selecione uma data e horário no calendário.
- **Cancelamento**: O agendamento pode ser cancelado, liberando o horário.

## 🧪 Testes

Você pode rodar os testes unitários e de integração executando:

```bash
flutter test
````
## 📂 Arquivos Ignorados

No `.gitignore` do projeto, os seguintes arquivos/diretórios são ignorados:

- `*.class`, `*.log`, `*.pyc`
- `.dart_tool/`, `.pub-cache/`, `/build/`
- Arquivos do Android Studio: `.idea/`, `.vscode/`

## 🤝 Contribuindo

Sinta-se à vontade para contribuir com este projeto. Siga os passos abaixo:

1. Faça um fork do projeto.
2. Crie uma branch para sua feature (`git checkout -b feature/minha-feature`).
3. Faça commit das suas alterações (`git commit -am 'Adiciona minha feature'`).
4. Faça push para a branch (`git push origin feature/minha-feature`).
5. Abra um Pull Request.



## 📄 Licença

Este projeto está licenciado sob a licença MIT - veja o arquivo [LICENSE](LICENSE) para mais detalhes.

---

Feito com ❤️ por [Kennedy Ramos](https://github.com/KennnedyRamos)
## 👤 Contato

**Desenvolvedor**: Kennedy Ramos  
**Email**: [kennedy_ramos9@icloud.com](mailto:kennedy_ramos9@icloud.com)  
**LinkedIn**: [linkedin.com/in/kennedy-ramos](https://www.linkedin.com/in/kennedy-silva-ramos-566b00150/)

Conecte-se conosco nas redes sociais:  
🔗 [Instagram](https://www.instagram.com/kennedyramos_/) | 🌐 [Site Oficial](https://kennnedyramos.github.io/meu-postifolio-web/)

## Supabase Storage (setup rapido)

### 1) Criar bucket
- Bucket: `barbershop-images`
- Public: ON
- Allowed mime types: `image/jpeg`, `image/png`, `image/webp`
- File size limit: 2MB

### 2) Policies (por usuario)
Cole no SQL Editor do Supabase:

```sql
-- INSERT
create policy "barbershops insert (own folder)"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'barbershop-images'
  and name like 'barbershops/' || auth.uid() || '/%'
);

-- UPDATE (upsert)
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
```

### 3) Rodar com dart-define

PowerShell:
```
$env:SUPABASE_URL="https://YOUR_PROJECT.supabase.co"
$env:SUPABASE_ANON_KEY="YOUR_ANON_KEY"
./scripts/run_debug.ps1
```

Ou build:
```
./scripts/build_debug_apk.ps1
```
