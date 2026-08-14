# Rakamin AI Interview Platform — local development
#
# The repo requires Ruby 3.3.2, Postgres and Redis. Rather than assume a
# reviewer has all three at the right versions, everything runs in Docker.
#
#   make setup   first time, from a clean checkout
#   make up      start everything
#   make test    run the full suite the way CI runs it

COMPOSE := docker compose -f infra/docker-compose.yml

.DEFAULT_GOAL := help
.PHONY: help setup up down restart rebuild logs ps console shell db-migrate db-rollback db-seed db-reset test test-api test-web typecheck token clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

setup: ## First-time setup: build images, start services, migrate and seed
	@test -f infra/.env || cp infra/.env.example infra/.env
	$(COMPOSE) build
	$(COMPOSE) up -d postgres redis
	@echo "waiting for postgres and redis to report healthy..."
	@until [ "$$($(COMPOSE) ps --format json postgres | grep -c healthy)" -ge 1 ]; do sleep 2; done
	$(COMPOSE) run --rm api bundle exec rails db:migrate
	$(COMPOSE) run --rm api bundle exec rails db:seed
	$(COMPOSE) up -d
	@echo ""
	@echo "  api  http://localhost:3001/health"
	@echo "  web  http://localhost:5173"
	@echo ""
	@echo "  next: make token   # mint a dev JWT for VITE_DEV_TOKEN"

up: ## Start all services
	$(COMPOSE) up -d
	@echo "api http://localhost:3001/health   web http://localhost:5173"

down: ## Stop all services (data volumes survive)
	$(COMPOSE) down

restart: ## Restart the api and sidekiq containers
	$(COMPOSE) restart api sidekiq

rebuild: ## Rebuild images from scratch — required after a Gemfile or package.json change
	$(COMPOSE) build --no-cache
	$(COMPOSE) up -d --force-recreate

logs: ## Tail logs from every service
	$(COMPOSE) logs -f

ps: ## Show service status
	$(COMPOSE) ps

console: ## Rails console
	$(COMPOSE) run --rm api bundle exec rails console

shell: ## Bash shell in the api container
	$(COMPOSE) run --rm api bash

db-migrate: ## Run pending migrations
	$(COMPOSE) run --rm api bundle exec rails db:migrate

db-rollback: ## Roll back the last migration (STEP=n for more)
	$(COMPOSE) run --rm api bundle exec rails db:rollback STEP=$${STEP:-1}

db-seed: ## Run db/seeds.rb
	$(COMPOSE) run --rm api bundle exec rails db:seed

db-reset: ## Drop, recreate, migrate and seed. Destroys local data.
	$(COMPOSE) run --rm api bundle exec rails db:drop db:create db:migrate db:seed

test: test-api test-web typecheck ## Run everything CI runs

test-api: ## RSpec
	# db:migrate first: config/environments/test.rb does not set
	# config.active_record.maintain_test_schema, so Rails will not bring the
	# test database up to date on its own and rspec aborts on pending migrations.
	$(COMPOSE) run --rm -e RAILS_ENV=test api \
		bash -c "bundle exec rails db:migrate && bundle exec rspec $(SPEC)"

test-web: ## Vitest
	$(COMPOSE) run --rm web npm run test

typecheck: ## tsc --noEmit
	$(COMPOSE) run --rm web npx tsc --noEmit

token: ## Mint a dev JWT to paste into infra/.env as VITE_DEV_TOKEN
	@$(COMPOSE) run --rm api bundle exec rails runner \
		"puts JsonWebToken.encode({ user_id: 1, role: 'admin', scheme: 'test-corp' })"

clean: ## Stop everything and delete the database and redis volumes
	$(COMPOSE) down -v
