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
docker compose up -d

# Check if database is ready
docker compose ps

# View logs
docker compose logs -f postgres
```

### Option 2: Start with Full Test Data (50,000 securities)
```bash
# This will destroy any existing data and load 50K securities
./scripts/recreate-full-db.sh
```

### Stopping the Database

```bash
# Stop containers
docker compose down

# Stop and remove volumes (deletes all data)
docker compose down -v
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

# Run queries directly via psql
./scripts/psql.sh
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
-- See sql/08-flexible-inheritance-query.sql for detailed holdings with inheritance
-- This query efficiently traverses the hierarchy and inherits attributes
-- Works with any hierarchy depth or structure
```

### Aggregate by Region and Sector
```sql
-- See sql/09-flexible-inheritance-aggregation.sql for aggregation examples
-- See INHERITANCE_GUIDE.md for detailed optimization techniques
```

## Key Documentation

- **[INHERITANCE_GUIDE.md](INHERITANCE_GUIDE.md)** - Complete guide to attribute inheritance
- **[sql/08-flexible-inheritance-query.sql](sql/08-flexible-inheritance-query.sql)** - Flexible inheritance query
- **[sql/09-flexible-inheritance-aggregation.sql](sql/09-flexible-inheritance-aggregation.sql)** - Aggregation queries

## Project Structure

```
portfolio-db/
├── docker-compose.yml     # Docker configuration
├── .env                  # Environment variables
├── README.md            # This file
├── sql/                 # SQL scripts
│   ├── 01-schema.sql   # Database schema
│   ├── 06-massive-hierarchy.sql # Hierarchy structure setup
│   ├── 06-massive-hierarchy-data-only.sql # Data generation
│   ├── 08-flexible-inheritance-query.sql # Flexible inheritance
│   ├── 09-flexible-inheritance-aggregation.sql # Aggregation queries
│   └── 99-massive-data-load.sql # Full data load
├── scripts/            # Helper scripts
│   ├── psql.sh        # Connect to database
│   ├── setup.sh       # Initial setup
│   ├── recreate-full-db.sh # Load full test data
│   └── test-performance.sh # Performance testing
└── data/              # PostgreSQL data (created automatically)
    └── postgres/      # Database files
```

## Customization

### Adding New Fact Tables

1. Create the table in `sql/01-schema.sql`
2. Add metadata entries to define inheritable attributes
3. Update queries to include the new fact table

### Modifying Data

The database uses auto-generated data with a hierarchical structure:
- Master funds at the top level
- Regional and strategy funds in middle layers  
- Securities at the leaf level
- See `sql/06-massive-hierarchy.sql` for the structure

## Troubleshooting

### Database Won't Start
```bash
# Check logs
docker compose logs postgres

# Reset everything
docker compose down -v
docker compose up -d
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