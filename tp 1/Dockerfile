# Use versioned base image - avoid 'latest' for security
FROM python:3.12-slim

WORKDIR /app

# Copy dependency file first for better layer caching
COPY app/requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app/ ./app/

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
