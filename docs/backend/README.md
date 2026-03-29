# Cadastro de Escola no Backend

## Fonte de verdade

A API real usada por este app esta em:

`/opt/lampp/htdocs/reserva_escolar_api_v2`

Os arquivos desta pasta `docs/backend` sao referencias de apoio para leitura e onboarding.
Se houver qualquer diferenca entre estes exemplos e a API real, priorize sempre os arquivos do backend real.

Status verificado nesta maquina:

- `login.php`: compativel com o app
- `logout.php`: compativel com o app
- `get_all_bookings.php`: compativel com o app
- `register_school.php`: existe na API real e o app foi ajustado para o contrato dele
- `change_my_password.php`: esperado pelo app para troca da propria senha

Este app agora espera um endpoint `register_school.php` para criar:

1. a escola
2. o primeiro tecnico
3. o vinculo entre os dois

## Contrato esperado

Requisicao:

```json
POST /register_school.php
{
  "school_name": "Escola Estadual Exemplo",
  "school_code": "ESC001",
  "admin_name": "Maria Souza",
  "admin_email": "tecnico@escola.com",
  "admin_password": "123456"
}
```

Resposta de sucesso:

```json
{
  "success": true,
  "message": "Escola cadastrada com sucesso.",
  "data": {
    "school_id": 1,
    "school_name": "Escola Estadual Exemplo",
    "school_code": "ESC001",
    "technician_id": 10,
    "technician_email": "tecnico@escola.com"
  }
}
```

Resposta de erro:

```json
{
  "success": false,
  "message": "Ja existe uma escola com esse codigo."
}
```

## Arquivos de referencia

- SQL base: [register_school.sql](/home/agacy-junior/RESERVA_ESCOLAR/reserva_escolar_v2_app/docs/backend/register_school.sql)
- Endpoint exemplo: [register_school.php.example](/home/agacy-junior/RESERVA_ESCOLAR/reserva_escolar_v2_app/docs/backend/register_school.php.example)
- Login exemplo: [login.php.example](/home/agacy-junior/RESERVA_ESCOLAR/reserva_escolar_v2_app/docs/backend/login.php.example)
- Logout exemplo: [logout.php.example](/home/agacy-junior/RESERVA_ESCOLAR/reserva_escolar_v2_app/docs/backend/logout.php.example)
- Troca de senha exemplo: [change_my_password.php.example](/home/agacy-junior/RESERVA_ESCOLAR/reserva_escolar_v2_app/docs/backend/change_my_password.php.example)
- Middleware de auth: [auth_guard.php.example](/home/agacy-junior/RESERVA_ESCOLAR/reserva_escolar_v2_app/docs/backend/auth_guard.php.example)
- Listagem admin: [get_all_bookings.php.example](/home/agacy-junior/RESERVA_ESCOLAR/reserva_escolar_v2_app/docs/backend/get_all_bookings.php.example)

## Como isso conversa com o app

- O Flutter chama `register_school.php` por meio de `ApiService.registerSchool(...)`.
- Quando o cadastro retorna `success: true`, a tela volta ao login.
- O login fica preenchido com `school_code` e `admin_email`.
- O tecnico informa a senha criada e entra normalmente usando o fluxo atual de `login.php`.

## Contrato esperado do login

Requisicao:

```json
POST /login.php
{
  "school_code": "ESC001",
  "email": "tecnico@escola.com",
  "password": "123456"
}
```

Resposta de sucesso:

```json
{
  "success": true,
  "message": "Login realizado com sucesso.",
  "data": {
    "id": 10,
    "school_id": 1,
    "name": "Maria Souza",
    "email": "tecnico@escola.com",
    "role": "technician",
    "school_name": "Escola Estadual Exemplo",
    "school_code": "ESC001",
    "api_token": "TOKEN_AQUI",
    "api_token_expires_at": "2026-03-16 20:30:00"
  }
}
```

Esses campos precisam existir porque o app monta o usuario autenticado a partir deles.

## Contrato esperado do logout

Requisicao:

```http
POST /logout.php
Authorization: Bearer TOKEN_AQUI
Content-Type: application/json

{}
```

Resposta de sucesso:

```json
{
  "success": true,
  "message": "Logout realizado com sucesso."
}
```

## Contrato esperado de `change_my_password.php`

Requisicao:

```http
POST /change_my_password.php
Authorization: Bearer TOKEN_AQUI
Content-Type: application/json

{
  "school_id": 1,
  "user_id": 10,
  "current_password": "123456",
  "new_password": "654321"
}
```

Observacoes:

- o endpoint deve validar o `Bearer` e garantir que o usuario autenticado bate com `user_id`
- `school_id` deve ser conferido com a escola do usuario autenticado
- a senha atual precisa ser validada antes da troca
- a nova senha deve ter pelo menos 6 caracteres

Resposta de sucesso:

```json
{
  "success": true,
  "message": "Senha atualizada com sucesso."
}
```

Resposta de erro:

```json
{
  "success": false,
  "message": "A senha atual informada nao confere."
}
```

## Como reutilizar a autenticacao Bearer

O arquivo [auth_guard.php.example](/home/agacy-junior/RESERVA_ESCOLAR/reserva_escolar_v2_app/docs/backend/auth_guard.php.example) resolve tres pontos:

1. extrair o token `Bearer`
2. validar se o token existe e ainda nao expirou
3. opcionalmente exigir perfis como `technician`

Exemplo de uso em um endpoint administrativo:

```php
require_once __DIR__ . '/auth_guard.php.example';

$user = auth_require_user($pdo);
auth_require_role($user, ['technician']);
```

Isso encaixa com o app atual, porque o Flutter envia `Authorization: Bearer ...` automaticamente depois do login.

## Contrato esperado de `get_all_bookings.php`

Esse endpoint alimenta:

- painel de agendamentos do tecnico
- relatorios administrativos

Requisicao:

```http
GET /get_all_bookings.php?school_id=1&booking_date=2026-03-16
Authorization: Bearer TOKEN_AQUI
```

Observacoes:

- `school_id` continua vindo do app, mas o endpoint deve validar se ele bate com a escola do usuario autenticado
- `booking_date` e opcional
- somente `technician` deve acessar

Resposta de sucesso:

```json
{
  "success": true,
  "data": [
    {
      "id": 12,
      "booking_date": "2026-03-16",
      "purpose": "Aula pratica de ciencias",
      "status": "scheduled",
      "cancelled_at": null,
      "resource_name": "Laboratorio 01",
      "user_name": "Joao Silva",
      "class_group_name": "1 Ano A",
      "subject_name": "Ciencias",
      "lessons": [
        {
          "id": 3,
          "lesson_number": 1,
          "label": "1a Aula"
        }
      ]
    }
  ]
}
```

Esse formato precisa ser preservado porque o app faz parse direto para `BookingAdminModel`.

## Ajustes comuns no backend real

- trocar `password_hash` pelo campo de senha ja usado na sua API, se existir
- mover conexao PDO para arquivo compartilhado de configuracao
- remover o campo `debug` em producao
- padronizar mensagens e status HTTP com os outros endpoints da API
- validar permissoes, logs e limites de criacao conforme a regra da rede escolar
