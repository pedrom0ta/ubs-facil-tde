# UBS Fácil

Aplicativo de agendamento, fila em tempo real e lembretes para Unidades Básicas de Saúde.
Implementação da documentação do projeto: **app Flutter** (Android/iOS) + **API REST em Python/FastAPI**.

```
ubs-facil/
├── backend/            API FastAPI (Python 3.11+)
│   ├── app/
│   │   ├── core/       configuração, banco, segurança (bcrypt, JWT, CPF/CNS), relógio
│   │   ├── api/routes/ auth, unidades, agendamentos, fila (+ recepção), perfil
│   │   ├── services/   regras de agenda, fila/WebSocket, lembretes/FCM, adaptador HL7 FHIR
│   │   ├── models.py   tabelas (SQLAlchemy 2.0)
│   │   ├── schemas.py  contratos de entrada/saída (Pydantic)
│   │   └── seed.py     dados de demonstração
│   └── tests/          30 testes automatizados (pytest)
├── mobile/             App Flutter com Clean Architecture
│   └── lib/
│       ├── core/       tema, cliente HTTP, armazenamento seguro, rotas, utilitários, widgets
│       └── features/   auth, onboarding, home, agendamento, fila, lembretes, historico, perfil
│           └── <feature>/domain | data | presentation
└── docker-compose.yml  API + PostgreSQL
```

---

## 1. Rodando a API

Requisitos: Python 3.11 ou superior.

```bash
cd backend
python -m venv .venv
# Windows: .venv\Scripts\activate      Linux/macOS: source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env            # opcional: ajuste as variáveis
python -m app.seed              # cria o banco SQLite com dados de demonstração
uvicorn app.main:app --reload --host 0.0.0.0
```

- Documentação interativa (Swagger): **http://localhost:8000/docs**
- Testes: `pytest` (dentro de `backend/`)
- Com Docker e PostgreSQL: `docker compose up --build` na raiz do projeto

**Contas de demonstração** (criadas pelo `seed`):

| Perfil    | CPF            | Senha        |
|-----------|----------------|--------------|
| Paciente  | 529.982.247-25 | ubsfacil123  |
| Recepção  | 111.444.777-35 | ubsfacil123  |

Em dias úteis, o seed também coloca 3 pacientes fictícios na fila de Clínica Geral da UBS Centro, para você ver a fila andando.

## 2. Rodando o app

Requisitos: Flutter 3.27 ou superior (`flutter doctor` sem erros).

```bash
cd mobile
flutter create --platforms=android,ios --org br.gov.ubsfacil --project-name ubs_facil .
flutter pub get
flutter run                                              # emulador Android
flutter run --dart-define=API_URL=http://192.168.0.10:8000   # celular físico (use o IP do seu PC)
```

O primeiro comando gera as pastas `android/` e `ios/`, que não vão no projeto. Ele também cria um `test/widget_test.dart` de exemplo, que deve ser apagado. No Linux/macOS, `bash tool/setup.sh` faz tudo isso e também ajusta o Android.

**Android e API sem HTTPS (só em desenvolvimento):** em `android/app/src/main/AndroidManifest.xml`, adicione antes de `<application`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```
e, dentro da tag `<application ...>`, o atributo `android:usesCleartextTraffic="true"`.

Testes do app: `flutter test`.

## 3. Demonstração ponta a ponta (jornada do usuário)

1. **Onboarding → Primeiro acesso:** crie uma conta (CPF e CNS válidos) ou entre com a conta de demonstração.
2. **Agendar:** Início → Agendar consulta → unidade, especialidade, dia e horário → confirmar.
3. **Lembretes:** são gerados automaticamente para 24h e 2h antes e aparecem em *Lembretes* (e como push, se o Firebase estiver configurado).
4. **Check-in:** no dia da consulta (a partir de 2h antes), vá em *Fila* → *Check-in*.
5. **Fila:** a posição e o tempo estimado são atualizados em tempo real via WebSocket.
6. **Chamar o paciente** (simulando o painel da recepção), em http://localhost:8000/docs:
   `POST /auth/login` com a conta da recepção → *Authorize* com o token →
   `POST /recepcao/chamar-proximo` `{"unidade_id": 1, "especialidade_id": 1, "consultorio": "Consultório 2"}`.
   Quem passar a ser o 1º da fila recebe o aviso "Você é o próximo".
7. **Finalizar:** `POST /recepcao/agendamentos/{id}/finalizar` → o atendimento vai para o *Histórico*.

> Para testar o check-in fora do horário, agende para hoje (se ainda houver horários livres) ou ajuste `CHECKIN_ANTES_MIN` no `.env`.

## 4. Requisitos atendidos

| Requisito | Onde |
|---|---|
| RF01 Cadastro (CPF e CNS) | `POST /auth/cadastro` · `cadastro_page.dart`. Valida os dígitos do CPF e do CNS e exige o aceite LGPD |
| RF02 Login | `POST /auth/login` (JWT) · `login_page.dart`. Bloqueia após 5 tentativas erradas |
| RF03 Agendamento | `GET /unidades/{id}/dias` e `/horarios`, `POST /agendamentos` · `agendar_page.dart` |
| RF04 Cancelamento | `POST /agendamentos/{id}/cancelar` · confirmação dupla; a vaga é liberada na hora |
| RF05 Reagendamento | `PATCH /agendamentos/{id}` · `agendar_page.dart` em modo reagendar |
| RF06 Check-in digital | `POST /agendamentos/{id}/checkin`: janela de 2h antes até 30 min depois; gera a senha (ex.: C-004) |
| RF07 Fila em tempo real | `WS /fila/ws` + `GET /fila/minha` (reserva por polling) · `fila_page.dart` |
| RF08 Notificações/lembretes | lembretes de 24h e 2h, avisos de "próximo" e "chamado" · `GET /notificacoes` · FCM opcional |
| RF09 Histórico | `GET /historico?tipo=` · filtros Consultas / Exames / Vacinas |
| RF10 Perfil | `GET/PATCH /perfil`, unidades favoritas, token de push |

**Não funcionais**
- **Segurança:** senhas com bcrypt, JWT com expiração e token no Keychain/Keystore (`flutter_secure_storage`). Cada paciente só acessa os próprios dados (o teste `test_paciente_nao_acessa_dados_de_outro` cobre isso). A API envia cabeçalhos de segurança e `Cache-Control: no-store`. Em produção, publique atrás de HTTPS.
- **LGPD:** consentimento registrado com data e hora, `GET /perfil/exportar` (portabilidade), `DELETE /perfil` (eliminação) e CPF mascarado na tela.
- **Acessibilidade:** contraste mínimo de 4,5:1, botões com 52 px de altura (acima de 48 dp) e rótulos para o TalkBack e o VoiceOver (`Semantics`). A fila e os alertas são anunciados ao leitor de tela, e o perfil tem a opção "Texto maior", que se soma à fonte do sistema.
- **Usabilidade (heurísticas de Nielsen):** dias passados e horários ocupados ficam bloqueados, e as mensagens de erro são escritas em linguagem simples, direto pela API. Cancelar e excluir a conta pedem confirmação.
- **Manutenibilidade:** Clean Architecture no app (domain / data / presentation por feature) e camadas na API (rotas → serviços → modelos).

## 5. Decisões técnicas (itens "a definir" na documentação)

| Item | Decisão | Motivo |
|---|---|---|
| Back-end | **Python + FastAPI** | Gera a documentação OpenAPI automaticamente, tem WebSocket nativo, é simples de manter e de testar |
| Banco de dados | **Relacional**: SQLite no desenvolvimento, PostgreSQL em produção | Agendamento exige integridade: um índice único parcial impede reservar o mesmo horário duas vezes, mesmo em requisições simultâneas |
| Comunicação da fila | **WebSocket**, com polling de 15 s como reserva | Atualização instantânea; se a rede bloquear o WebSocket, o app passa a consultar periodicamente |
| Integração e-SUS | **Adaptador HL7 FHIR R4** (`services/fhir.py`, `GET /agendamentos/{id}/fhir`) | Converte agendamentos e pacientes para recursos `Appointment` e `Patient` com identificadores da RNDS. O envio real exige credenciamento do município |
| Login | **CPF + senha** | O mockup mostrava CPF + CNS, mas o número do CNS fica impresso no cartão e não serve como segredo. O CNS é pedido no cadastro, e a seção de segurança da documentação prevê "CPF e senha/token" |

## 6. Próximos passos sugeridos
- Painel web da recepção, usando os endpoints `/recepcao/*`, que já existem.
- Migrações com Alembic e deploy em nuvem (o Dockerfile já está pronto).
- Firebase: `flutterfire configure`, descomentar as dependências no `pubspec.yaml` e trocar `NoopPushService` por `FcmPushService` (veja `core/push/push_service.dart`).
- Check-in com confirmação de localização (geofence da UBS).
