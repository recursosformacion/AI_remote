FROM python:3.11-slim

WORKDIR /app

RUN pip install --no-cache-dir --upgrade pip

COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY app.py /app/app.py
COPY prompt_builder.py /app/prompt_builder.py
COPY json_processing.py /app/json_processing.py
COPY json_contract.py /app/json_contract.py
COPY xml_extractor.py /app/xml_extractor.py

EXPOSE 8000

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
