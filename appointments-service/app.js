const express = require("express");
const bodyParser = require("body-parser");

const app = express();

// Middleware
app.use(bodyParser.json());

// Sample data
let appointments = [
  { id: 1, patient: "John Doe", date: "2024-12-01", time: "10:00 AM" },
  { id: 2, patient: "Jane Doe", date: "2024-12-02", time: "11:00 AM" },
];

// Health check endpoint
app.get("/health", (req, res) => {
  res.status(200).send({ status: "OK" });
});

// Get all appointments
app.get("/appointments", (req, res) => {
  res.status(200).send(appointments);
});

// Get an appointment by ID
app.get("/appointments/:id", (req, res) => {
  const id = parseInt(req.params.id);
  const appointment = appointments.find((appt) => appt.id === id);

  if (appointment) {
    res.status(200).send(appointment);
  } else {
    res.status(404).send({ message: "Appointment not found" });
  }
});

// Add a new appointment
app.post("/appointments", (req, res) => {
  const newAppointment = {
    id: appointments.length + 1,
    patient: req.body.patient,
    date: req.body.date,
    time: req.body.time,
  };

  appointments.push(newAppointment);
  res.status(201).send(newAppointment);
});

// Delete an appointment by ID
app.delete("/appointments/:id", (req, res) => {
  const id = parseInt(req.params.id);
  appointments = appointments.filter((appt) => appt.id !== id);

  res.status(200).send({ message: "Appointment deleted successfully" });
});

// Export the app for use in other modules
module.exports = app;
