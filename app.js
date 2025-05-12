/**
 * Backend API Server Application
 * 
 * This Express.js application serves as the API backend for our e-commerce store.
 * It connects to a PostgreSQL database and provides product data via RESTful endpoints.
 * 
 * Main responsibilities:
 * 1. Connect to the PostgreSQL database
 * 2. Provide RESTful API endpoints for product data
 * 3. Handle database initialization and schema adaptation
 * 4. Provide health check endpoints for monitoring
 */

const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
const app = express();
const port = process.env.PORT || 8080;

// Enable CORS for cross-origin requests (necessary for frontend-backend communication)
app.use(cors());

// Parse JSON request bodies
app.use(express.json());

/**
 * PostgreSQL connection pool configuration
 * 
 * Using environment variables for secure and flexible configuration
 * Connection pooling improves performance by reusing connections
 */
const pool = new Pool({
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  port: process.env.DB_PORT || 5432,
});

// Log pool errors to help with debugging database issues
pool.on('error', (err) => {
  console.error('Unexpected PostgreSQL pool error:', err.message);
});

/**
 * Global variable to store the determined primary key column name
 * This prevents us from having to query the database schema repeatedly
 */
let PRIMARY_KEY_COLUMN = null;

/**
 * Gets the primary key column name for the products table
 * 
 * This function examines the database schema to determine which column
 * is being used as the primary key ('id' or 'product_id').
 * 
 * @returns {Promise<string>} The name of the primary key column
 */
async function getPrimaryKeyColumn() {
  // Return cached value if available
  if (PRIMARY_KEY_COLUMN) {
    return PRIMARY_KEY_COLUMN;
  }
  
  try {
    // Query the database for column information
    const columnInfo = await pool.query(`
      SELECT column_name
      FROM information_schema.columns
      WHERE table_name = 'products'
    `);
    
    const columns = columnInfo.rows.map(col => col.column_name);
    console.log('Available columns:', columns);
    
    // Determine the primary key column name based on common conventions
    if (columns.includes('id')) {
      PRIMARY_KEY_COLUMN = 'id';
    } else if (columns.includes('product_id')) {
      PRIMARY_KEY_COLUMN = 'product_id';
    } else {
      // Use the first column as a fallback
      PRIMARY_KEY_COLUMN = columns[0];
    }
    
    console.log(`Using ${PRIMARY_KEY_COLUMN} as primary key column`);
    return PRIMARY_KEY_COLUMN;
  } catch (err) {
    console.error('Error determining primary key column:', err);
    // Default to product_id if we can't determine
    return 'product_id';
  }
}

/**
 * Initializes the database connection, creates tables if they don't exist,
 * and populates with sample data if empty
 */
async function initializeDatabase() {
  try {
    console.log('Attempting to initialize database...');
    
    // First, check if the products table exists
    const tableCheck = await pool.query(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'products'
      )
    `);
    
    const tableExists = tableCheck.rows[0].exists;
    console.log('Products table exists:', tableExists);
    
    if (!tableExists) {
      // Create products table if it doesn't exist
      console.log('Creating products table...');
      await pool.query(`
        CREATE TABLE products (
          product_id SERIAL PRIMARY KEY,
          name VARCHAR(100) NOT NULL,
          description TEXT,
          price NUMERIC(10,2) NOT NULL,
          image_url TEXT,
          stock_quantity INTEGER DEFAULT 0,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
      console.log('Products table created successfully');
      
      // Insert sample data
      await insertSampleProducts();
    } else {
      // Table exists, check if it's empty
      const countResult = await pool.query('SELECT COUNT(*) FROM products');
      console.log(`Found ${countResult.rows[0].count} existing products`);
      
      if (parseInt(countResult.rows[0].count) === 0) {
        console.log('Products table is empty, inserting sample data...');
        await insertSampleProducts();
      }
    }
    
    // Determine the primary key column
    const idColumn = await getPrimaryKeyColumn();
    console.log(`Database initialized. Using ${idColumn} as primary key.`);
    
  } catch (err) {
    console.error('Error initializing database:', err);
    console.error('Error details:', err.stack);
  }
}

/**
 * Helper function to insert sample products into the database
 */
async function insertSampleProducts() {
  try {
    await pool.query(`
      INSERT INTO products (name, description, price, image_url, stock_quantity) VALUES
      ('Smartphone X', 'Latest smartphone with advanced features', 699.99, 'https://via.placeholder.com/150', 25),
      ('Laptop Pro', 'High-performance laptop for professionals', 1299.99, 'https://via.placeholder.com/150', 15),
      ('T-shirt Basic', 'Comfortable cotton t-shirt', 19.99, 'https://via.placeholder.com/150', 100),
      ('Kitchen Mixer', 'Powerful kitchen mixer for baking', 149.99, 'https://via.placeholder.com/150', 10)
    `);
    console.log('Sample products inserted into database');
  } catch (err) {
    console.error('Error inserting sample products:', err);
    throw err; // Re-throw to be handled by the caller
  }
}

// Initialize database when server starts
initializeDatabase();

/**
 * Health check endpoint
 * 
 * Used for monitoring and readiness/liveness probes in Kubernetes
 * Returns 200 OK if the database connection is healthy
 */
app.get('/api/health', (req, res) => {
  pool.query('SELECT 1', (err) => {
    if (err) {
      console.error('Health check failed:', err.message);
      return res.status(500).json({ status: 'error', message: 'Database connection failed' });
    }
    res.json({ status: 'ok', message: 'Service is healthy, database connected' });
  });
});

/**
 * GET /api/products endpoint
 * 
 * Returns all products from the database
 * Normalizes the response to ensure it has an 'id' property for frontend compatibility
 */
app.get('/api/products', async (req, res) => {
  try {
    console.log('GET /api/products: Fetching all products');
    
    // Get the primary key column name
    const idColumn = await getPrimaryKeyColumn();
    
    // Fetch all products, ordered by the primary key
    const result = await pool.query(`SELECT * FROM products ORDER BY ${idColumn}`);
    console.log(`Retrieved ${result.rows.length} products successfully`);
    
    // Normalize results to always have an 'id' property for frontend compatibility
    const normalizedResults = result.rows.map(product => {
      const normalizedProduct = { ...product };
      // Add an 'id' property if it doesn't exist
      if (!normalizedProduct.id && normalizedProduct[idColumn]) {
        normalizedProduct.id = normalizedProduct[idColumn];
      }
      return normalizedProduct;
    });
    
    // Return the normalized product data
    res.json(normalizedResults);
  } catch (err) {
    console.error('Error fetching products:', err.message);
    console.error('Error stack:', err.stack);
    res.status(500).json({ error: 'Database error', details: err.message });
  }
});

/**
 * GET /api/products/:id endpoint
 * 
 * Returns a specific product by ID
 * Handles database schema differences by using the determined primary key column
 */
app.get('/api/products/:id', async (req, res) => {
  try {
    // Get the primary key column name
    const idColumn = await getPrimaryKeyColumn();
    
    // Query for the specific product
    const result = await pool.query(`SELECT * FROM products WHERE ${idColumn} = $1`, [req.params.id]);
    
    if (result.rows.length === 0) {
      // Return 404 if product not found
      res.status(404).json({ error: 'Product not found' });
    } else {
      // Normalize the result to include an 'id' property
      const product = { ...result.rows[0] };
      if (!product.id && product[idColumn]) {
        product.id = product[idColumn];
      }
      res.json(product);
    }
  } catch (err) {
    console.error('Error fetching product:', err);
    res.status(500).json({ error: 'Database error', details: err.message });
  }
});

/**
 * Start the server and listen for incoming connections
 * '0.0.0.0' ensures the server listens on all network interfaces
 */
app.listen(port, '0.0.0.0', () => {
  console.log(`Backend server running on port ${port}`);
});