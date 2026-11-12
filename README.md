# README

# Tholos

Aplicación de finanzas personales: cuentas, movimientos, pagos recurrentes,
presupuestos, metas, inversiones y patrimonio neto.

## Requisitos
- Ruby 3.4.12
- PostgreSQL 17

## Puesta en marcha
```bash
bin/setup
bin/dev
```
Abrir http://localhost:3000

## Tests y calidad
```bash
bundle exec rspec
bin/rubocop
bin/brakeman --no-pager
```

## Despliegue
Nativo en el VPS (rbenv + Puma bajo systemd, detrás de Caddy). Primera instalación: nota KB-0004 de la bóveda.
```bash
ssh deploy@172.104.236.233 'cd ~/apps/tholos && git pull --ff-only && bin/deploy'
```

## Documentación
La documentación del proyecto (PRD, ADR, backlog) vive en la bóveda de Obsidian **Tholos**.

## Convenciones
- Dinero: `*_cents` (bigint) + `currency`.
- Todo dato pertenece a un `Household` (`Current.household`).
- Commits: Conventional Commits + ID de historia, p. ej. `feat(accounts): crear cuenta [US-0101]`.
