const express = require('express');
const app = express();

// Middleware to parse JSON bodies
app.use(express.json());

// In-memory data store (replace with a database in a real application)
let patients = [
  { id: '1', name: 'John Doe', age: 30, condition: 'Healthy' },
  { id: '2', name: 'Jane Smith', age: 45, condition: 'Hypertension' }
];

// Root route to avoid "Cannot GET /" error
app.get('/', (req, res) => {
  res.send('Welcome to the Patient Service');
});

// Health check route
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'OK', service: 'Patient Service' });
});

// Get all patients
app.get('/patients', (req, res) => {
  res.json({ 
    message: 'Patients retrieved successfully',
    count: patients.length,
    patients: patients 
  });
});

// Get a specific patient by ID
app.get('/patients/:id', (req, res) => {
  const patient = patients.find(p => p.id === req.params.id);
  if (patient) {
    res.json({ 
      message: 'Patient found',
      patient: patient 
    });
  } else {
    res.status(404).json({ error: 'Patient not found' });
  }
});

// Add a new patient
app.post('/patients', (req, res) => {
  try {
    const { name, age, condition } = req.body;
    if (!name || !age) {
      return res.status(400).json({ error: 'Name and age are required' });
    }
    const newPatient = {
      id: (patients.length + 1).toString(),
      name,
      age,
      condition: condition || 'Not specified'
    };
    patients.push(newPatient);
    res.status(201).json({ 
      message: 'Patient added successfully',
      patient: newPatient 
    });
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = app; // Export app to be used in index.js
