# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Twenty is an open-source CRM built with modern web technologies. It features a full-stack architecture with:
- **Frontend**: React + TypeScript + Recoil + Emotion
- **Backend**: NestJS + GraphQL + TypeORM + PostgreSQL
- **Deployment**: Docker + Docker Compose + Nix/Arion
- **Build System**: Nx monorepo with Yarn workspaces

## Architecture

### Monorepo Structure
- `packages/twenty-front/` - React frontend application
- `packages/twenty-server/` - NestJS backend API
- `packages/twenty-ui/` - Shared UI component library
- `packages/twenty-shared/` - Shared utilities and types
- `packages/twenty-emails/` - Email templates and components
- `packages/twenty-docker/` - Docker configuration and deployment scripts
- `packages/twenty-website/` - Marketing website (Next.js)
- `packages/twenty-chrome-extension/` - Chrome extension
- `packages/twenty-zapier/` - Zapier integration
- `packages/twenty-e2e-testing/` - End-to-end tests (Playwright)

### Key Technologies
- **Package Manager**: Yarn 4.4.0 (Berry)
- **Build Tool**: Nx 18.3.3 for monorepo orchestration
- **Testing**: Jest for unit tests, Playwright for E2E
- **Linting**: ESLint with custom rules, Prettier for formatting
- **Database**: PostgreSQL with TypeORM
- **Queue**: BullMQ with Redis
- **GraphQL**: Apollo Server with code generation

## Common Development Commands

### Getting Started
```bash
# Install dependencies
yarn install

# Start development environment (frontend + backend + worker)
yarn start

# Alternative: start individual services
npx nx start twenty-server
npx nx start twenty-front
npx nx run twenty-server:worker
```

### Build & Test
```bash
# Build all packages
npx nx run-many -t build

# Run tests
npx nx test <project-name>          # Single project
npx nx run-many -t test             # All projects

# Run E2E tests
npx nx test:e2e twenty-e2e-testing
```

### Linting & Formatting
```bash
# Lint code
npx nx lint <project-name>          # Single project
npx nx run-many -t lint             # All projects
npx nx lint <project-name> --fix    # Auto-fix issues

# Format code
npx nx fmt <project-name>           # Single project
npx nx run-many -t fmt              # All projects
npx nx fmt <project-name> --fix     # Auto-fix formatting

# Type checking
npx nx typecheck <project-name>     # Single project
npx nx run-many -t typecheck        # All projects
```

### Database Operations
```bash
# Setup local database with Docker
make postgres-on-docker
make redis-on-docker

# Run database migrations
npx nx run twenty-server:database:migrate

# Reset database
npx nx run twenty-server:database:reset
```

### Development Tools
```bash
# Generate GraphQL types
npx nx run twenty-front:graphql:generate

# Run Storybook
npx nx storybook:serve:dev twenty-front
npx nx storybook:serve:dev twenty-ui

# Chrome extension development
npx nx start twenty-chrome-extension
```

## Production Deployment

### Docker Compose (Primary Method)
```bash
# Clone the repo and navigate to docker directory
cd packages/twenty-docker

# Copy and configure environment
cp .env.example .env
# Edit .env with your configuration

# Generate app secret
openssl rand -base64 32

# Deploy with Docker Compose
docker compose up -d
```

### Environment Variables
Key variables for production deployment:
- `SERVER_URL`: Public URL of your instance
- `PG_DATABASE_PASSWORD`: PostgreSQL password
- `APP_SECRET`: Random secret for JWT tokens
- `STORAGE_TYPE`: `local` or `s3`
- Authentication providers (Google, Microsoft)
- SMTP configuration for emails

### NixOS Deployment (Recommended)
Twenty includes a Nix flake with Arion configuration for declarative deployment on NixOS:

```nix
{
  inputs.twenty = {
    url = "github:twentyhq/twenty";
  };

  outputs = { nixpkgs, twenty, ... }: {
    nixosConfigurations.myserver = nixpkgs.lib.nixosSystem {
      modules = [
        twenty.nixosModules.default
        {
          services.twenty-crm = {
            enable = true;
            serverUrl = "https://crm.example.com";
            port = 3000;
            
            # Secure secret management
            appSecretFile = "/run/secrets/twenty-app-secret";
            database.passwordFile = "/run/secrets/twenty-db-password";
            
            # Optional: S3 storage
            storage = {
              type = "s3";
              s3 = {
                region = "us-east-1";
                bucket = "my-twenty-storage";
              };
            };
            
            # Optional: Authentication providers
            auth.google = {
              enabled = true;
              clientIdFile = "/run/secrets/google-client-id";
              clientSecretFile = "/run/secrets/google-client-secret";
            };
            
            # Optional: Email configuration
            email = {
              driver = "smtp";
              fromAddress = "noreply@example.com";
              fromName = "My Company CRM";
              smtp = {
                host = "smtp.gmail.com";
                port = 587;
                userFile = "/run/secrets/smtp-user";
                passwordFile = "/run/secrets/smtp-password";
              };
            };
          };
        }
      ];
    };
  };
}
```

### Kubernetes Deployment
K8s manifests available in `packages/twenty-docker/k8s/` with Terraform support.

## Development Notes

### Code Style
- TypeScript strict mode enabled
- ESLint rules enforced with custom rules in `tools/eslint-rules/`
- Prettier for consistent formatting
- Emotion for CSS-in-JS styling

### GraphQL Development
- Schema-first approach with code generation
- Apollo Client for frontend queries
- Custom decorators for backend resolvers
- Automatic type generation with `@graphql-codegen`

### Testing Strategy
- Jest for unit tests with React Testing Library
- Playwright for E2E tests
- Storybook for component development and testing
- MSW for API mocking in tests

### State Management
- Recoil for global state management
- Apollo Client cache for GraphQL state
- Custom hooks for local component state

### Database
- PostgreSQL as primary database
- Redis for caching and job queues
- TypeORM for database operations
- Migration-based schema management

### Performance Considerations
- Nx caching for build optimization
- GraphQL query optimization with DataLoader
- React component memoization patterns
- Lazy loading for route components

## Troubleshooting

### Common Issues
1. **Node version**: Ensure Node.js 22.12.0 is installed
2. **Yarn version**: Use Yarn 4.4.0 (Berry)
3. **Database connection**: Verify PostgreSQL is running on port 5432
4. **Redis connection**: Ensure Redis is running on port 6379
5. **Port conflicts**: Default ports are 3000 (frontend), 3001 (backend)

### Environment Setup
- Use Docker for local database setup via Makefile
- Configure environment variables in `.env` files
- Check package-specific README files for additional setup

## Nix/Arion Integration

This repository includes a Nix flake that provides declarative deployment via Arion:
- **Arion configuration** (`arion-compose.nix`) - Nix-based Docker Compose equivalent
- **NixOS module** - Automatic systemd integration for NixOS servers
- **Declarative deployment** - Configuration managed through NixOS, not manual commands

### Files
- `flake.nix` - Nix flake exporting NixOS module
- `arion-compose.nix` - Twenty CRM service definitions in Nix

### Deployment
Import the flake in your NixOS configuration and rebuild. Twenty CRM containers will be automatically managed by systemd - no manual `arion up` or `docker compose` commands needed.

### Local Development
For local development and testing, you can use Arion directly:

```bash
# Install Arion (if not already available)
nix-shell -p arion

# Start Twenty CRM locally
arion up -d

# View logs
arion logs -f

# Stop services
arion down
```

The `arion-compose.nix` file includes sensible defaults for local development (localhost, default ports, etc.).

## Resources

- [Official Documentation](https://twenty.com/developers)
- [Self-hosting Guide](https://twenty.com/developers/section/self-hosting)
- [Local Setup Guide](https://twenty.com/developers/local-setup)
- [Docker Deployment](https://twenty.com/developers/section/self-hosting/docker-compose)
- [Arion Documentation](https://docs.hercules-ci.com/arion/)