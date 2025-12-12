# Prisma Schema for Terracare Ledger

This folder contains the Prisma schema for the backend database.

## Models
- **User**: Stores user addresses, roles, and settings.
- **Extension**: Tracks enabled/disabled extensions per user.
- **AnalyticsEvent**: Stores analytics and event logs for user actions.

## Usage
1. Set your `DATABASE_URL` in the backend `.env` file.
2. Run `npx prisma generate` to generate the Prisma client.
3. Run `npx prisma migrate dev --name init` to create the database tables.
