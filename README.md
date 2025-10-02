# Portfolio Holdings Database

A PostgreSQL database project implementing a hierarchical portfolio holdings model with multiple fact tables and attribute inheritance.

## Features

- **Hierarchical Structure**: Supports portfolio-to-portfolio and portfolio-to-security relationships
- **Multiple Fact Tables**: Separate tables for different attribute types (portfolio, risk, market data, fundamentals, ESG)
- **Attribute Inheritance**: Automatically inherits attributes from parent portfolios
- **Temporal Support**: Tracks positions and attributes over time
- **Sample Data**: Includes sample portfolios and securities for testing

## Quick Start

### Prerequisites
- Docker and Docker Compose
- PostgreSQL client tools (optional, for direct database access)

### Option 1: Start with Sample Data (6 securities)
```bash
# Start PostgreSQL container
docker-compose up -d

# Check if database is ready
docker-compose ps

# View logs
docker-compose logs -f postgres
```

### Option 2: Start with Full Test Data (50,000 securities)
```bash
# This will destroy any existing data and load 50K securities
./scripts/recreate-full-db.sh
```

### Stopping the Database

```bash
# Stop containers
docker-compose down

# Stop and remove volumes (deletes all data)
docker-compose down -v
```

## Database Access

### Connection Details
- Host: `localhost`
- Port: `5432`
- Database: `portfolio`
- Username: `portfolio_user`
- Password: `portfolio_pass123`

### Using Helper Scripts

```bash
# Connect to database CLI
./scripts/psql.sh

# Run example queries
./scripts/run-queries.sh

# Export query results to CSV
./scripts/export-holdings.sh > holdings.csv
```

### Direct Connection

```bash
# Using psql
psql -h localhost -p 5432 -U portfolio_user -d portfolio

# Connection string
postgresql://portfolio_user:portfolio_pass123@localhost:5432/portfolio
```

## Database Schema

### Core Tables

1. **instruments**: Master table for all portfolios and securities
2. **positions**: Defines parent-child relationships with quantities and weights
3. **fact_portfolio_attributes**: Portfolio-level attributes (inheritable)
4. **fact_risk_attributes**: Risk classification data (inheritable)
5. **fact_market_data**: Pricing and market data (leaf-only)
6. **fact_fundamentals**: Financial metrics (leaf-only)
7. **fact_esg_scores**: ESG ratings (can be at any level)

### Sample Data Structure

```
Global Tech Fund (Portfolio 1)
├── US Large Cap (Portfolio 2) - 70% weight
│   ├── AAPL - 2,800 shares (50% of sub-portfolio)
│   └── MSFT - 1,050 shares (50% of sub-portfolio)
└── Innovation Sleeve (Portfolio 3) - 30% weight
    └── GOOGL - 1,900 shares (100% of sub-portfolio)
```

## Example Queries

### Get All Holdings with Inherited Attributes
```sql
-- See sql/07-optimized-inheritance-query.sql for the full implementation
-- This query efficiently traverses the hierarchy and inherits attributes
-- Performance: ~150ms for 50,000 securities
```

### Aggregate by Region and Sector
```sql
-- See sql/03-queries.sql for basic examples
-- See INHERITANCE_GUIDE.md for detailed optimization techniques
```

## Key Documentation

- **[INHERITANCE_GUIDE.md](INHERITANCE_GUIDE.md)** - Complete guide to attribute inheritance
- **[sql/07-optimized-inheritance-query.sql](sql/07-optimized-inheritance-query.sql)** - Production-ready inheritance query

## Project Structure

```
portfolio-db/
├── docker-compose.yml     # Docker configuration
├── .env                  # Environment variables
├── README.md            # This file
├── sql/                 # SQL scripts
│   ├── 01-schema.sql   # Database schema
│   ├── 02-sample-data.sql # Sample data
│   └── 03-queries.sql  # Example queries
├── scripts/            # Helper scripts
│   ├── psql.sh        # Connect to database
│   ├── run-queries.sh # Run example queries
│   └── export-holdings.sh # Export data
└── data/              # PostgreSQL data (created automatically)
    └── postgres/      # Database files
```

## Customization

### Adding New Fact Tables

1. Create the table in `sql/01-schema.sql`
2. Add metadata entries to define inheritable attributes
3. Update queries to include the new fact table

### Modifying Sample Data

Edit `sql/02-sample-data.sql` to add or modify:
- Portfolios and securities
- Positions and weights
- Attribute values
- Dates and time periods

## Troubleshooting

### Database Won't Start
```bash
# Check logs
docker-compose logs postgres

# Reset everything
docker-compose down -v
docker-compose up -d
```

### Permission Issues
```bash
# Fix data directory permissions
sudo chown -R 999:999 ./data/postgres
```

### Connection Refused
- Ensure Docker is running
- Check if port 5432 is available
- Wait for health check to pass

## License

This project is for demonstration purposes.