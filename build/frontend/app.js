/**
 * Frontend Server Application
 * 
 * This Express.js application serves the web frontend for our e-commerce store.
 * It provides static content and proxies API requests to the backend service.
 * 
 * Main responsibilities:
 * 1. Serve static HTML, CSS, and JavaScript files
 * 2. Proxy API requests to the backend service
 * 3. Handle errors and provide debugging endpoints
 */

const express = require('express');
const http = require('http');
const app = express();
const port = process.env.PORT || 80;

// Get backend URL from environment or use default
// Using environment variables allows for flexible configuration across environments
const BACKEND_URL = process.env.API_URL || 'http://ecommerce-backend:8080';
console.log(`Using backend URL: ${BACKEND_URL}`);

/**
 * Serve static files from the 'public' directory
 * This includes HTML, CSS, images, and client-side JavaScript
 */
app.use(express.static('public'));

/**
 * Configuration information endpoint
 * Used for debugging to view current server configuration
 */
app.get('/config', (req, res) => {
  res.json({
    backendUrl: BACKEND_URL,
    environment: process.env
  });
});

/**
 * API proxy endpoint for products
 * 
 * Forwards requests to the backend service and handles responses
 * Includes error handling and response processing
 */
app.get('/api/products', (req, res) => {
  // Construct the backend URL
  const backendUrl = `${BACKEND_URL}/api/products`;
  console.log(`Proxying request to backend: ${backendUrl}`);
  
  // Make request to backend
  http.get(backendUrl, (backendRes) => {
    console.log(`Backend response status: ${backendRes.statusCode}`);
    let data = '';
    
    // Collect data chunks as they arrive
    backendRes.on('data', (chunk) => {
      data += chunk;
    });
    
    // Process complete response
    backendRes.on('end', () => {
      console.log(`Received response from backend: ${data.substring(0, 200)}...`);
      
      try {
        // Parse the JSON response
        const parsedData = JSON.parse(data);
        console.log('Parsed data type:', typeof parsedData);
        console.log('Is array:', Array.isArray(parsedData));
        
        // Validate response format - must be an array for the frontend
        if (!Array.isArray(parsedData)) {
          console.error('Backend response is not an array:', parsedData);
          res.status(500).json({ 
            error: 'Backend response format error', 
            received: typeof parsedData,
            data: parsedData
          });
          return;
        }
        
        // Forward the validated response to the client
        res.setHeader('Content-Type', 'application/json');
        res.send(JSON.stringify(parsedData));
      } catch (err) {
        // Handle JSON parsing errors
        console.error('Error parsing JSON from backend:', err);
        res.status(500).json({ 
          error: 'Error parsing backend response', 
          message: err.message,
          rawData: data.substring(0, 500) 
        });
      }
    });
  }).on('error', (err) => {
    // Handle network or connection errors
    console.error('Error connecting to backend service:', err.message);
    res.status(500).json({ 
      error: 'Error connecting to backend service',
      message: err.message,
      backendUrl: backendUrl
    });
  });
});

/**
 * Backend health check endpoint
 * Used for diagnosing connectivity issues between frontend and backend
 */
app.get('/debug/backend', (req, res) => {
  const healthUrl = `${BACKEND_URL}/api/health`;
  console.log(`Checking backend health at: ${healthUrl}`);
  
  http.get(healthUrl, (backendRes) => {
    let data = '';
    
    backendRes.on('data', (chunk) => {
      data += chunk;
    });
    
    backendRes.on('end', () => {
      res.send({
        status: 'Backend connection successful',
        statusCode: backendRes.statusCode,
        headers: backendRes.headers,
        data: data
      });
    });
  }).on('error', (err) => {
    res.status(500).send({
      status: 'Backend connection failed',
      error: err.message,
      healthUrl: healthUrl
    });
  });
});

/**
 * Start the server and listen for incoming connections
 * '0.0.0.0' ensures the server listens on all network interfaces
 */
app.listen(port, '0.0.0.0', () => {
  console.log(`Frontend server running on port ${port}`);
  console.log(`Backend URL: ${BACKEND_URL}`);
});
