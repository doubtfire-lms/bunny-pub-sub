# bunny-pub-sub

Example .env config for Overseer:

```env
RABBITMQ_HOSTNAME=192.254.254.254
RABBITMQ_USERNAME=guest
RABBITMQ_PASSWORD=guest
EXCHANGE_NAME=x_assessment
DURABLE_QUEUE_NAME=q_csharp
BINDING_KEYS=csharp
DEFAULT_BINDING_KEY=default_env
```

## Build process

```bash
gem build bunny-pub-sub.gemspec
push bunny-pub-sub-0.5.0.gem
```
