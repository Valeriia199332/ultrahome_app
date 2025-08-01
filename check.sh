# Скрипт для проверки WP-куки по JWT

# Замените строку ниже на свой свежий токен:
TOKEN="eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJodHRwczovL3VsdHJhaG9tZXNlcnZpY2VzLm5ldCIsImlhdCI6MTc1NDA2OTMwMCwibmJmIjoxNzU0MDY5MzAwLCJleHAiOjE3NTQ2NzQxMDAsImRhdGEiOnsidXNlciI6eyJpZCI6IjI2In19fQ.GQYuu7XoEjdIOTMXUg11DJVCEZz1dHJTl6ZQi3XdRH0"

# Выполняем запрос к вашему endpoint
curl -i -X GET \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  https://ultrahomeservices.net/wp-json/custom/v1/get-auth-cookies
