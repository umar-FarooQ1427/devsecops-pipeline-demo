# Use a lightweight official Python image as the base
FROM python:3.12-slim-trixie

# Set the working directory inside the container
WORKDIR /app

# Copy dependency file first (for caching efficiency)
COPY requirements.txt .

# Install dependencies inside the container
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application code
COPY . .

# Tell Docker which port the app listens on
EXPOSE 5000

# Command to run when the container starts
CMD ["python", "app.py"]