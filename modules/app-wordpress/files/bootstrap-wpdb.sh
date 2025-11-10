set -euo pipefail
echo "HOST=${MYSQL_HOST} PORT=${MYSQL_PORT} ADMIN=${MYSQL_LOGIN_USER} TARGET_DB=${TARGET_DATABASE} TARGET_USER=${TARGET_USER}"

required_vars=(
  MYSQL_HOST
  MYSQL_PORT
  MYSQL_LOGIN_USER
  MYSQL_LOGIN_PASSWORD
  TARGET_DATABASE
  TARGET_USER
  TARGET_USER_PASSWORD
)

for v in "${required_vars[@]}"; do
  val="$(eval "printf '%s' \"\${$v:-}\"")"
  if [ -z "$val" ]; then
    echo "ERROR: $v is empty"
    exit 1
  fi
done

for i in $(seq 1 60); do
  if mysql --connect-timeout=5 ${MYSQL_SSL_MODE:+--ssl-mode=${MYSQL_SSL_MODE}} \
      --protocol=TCP -h "$MYSQL_HOST" -P "$MYSQL_PORT" \
      -u "$MYSQL_LOGIN_USER" -p"$MYSQL_LOGIN_PASSWORD" \
      -e "SELECT 1" >/dev/null 2>&1; then
    echo "MySQL reachable"
    break
  fi
  echo "Retry $i/60 waiting for MySQL"
  sleep 5
  if [ "$i" -eq 60 ]; then
    echo "ERROR: Timeout reaching MySQL"
    exit 1
  fi
done

echo "Creating database ${TARGET_DATABASE} if it does not exist"
mysql --connect-timeout=5 ${MYSQL_SSL_MODE:+--ssl-mode=${MYSQL_SSL_MODE}} \
  --protocol=TCP -h "$MYSQL_HOST" -P "$MYSQL_PORT" \
  -u "$MYSQL_LOGIN_USER" -p"$MYSQL_LOGIN_PASSWORD" \
  -e "CREATE DATABASE IF NOT EXISTS \`${TARGET_DATABASE}\`;"

echo "Ensuring user ${TARGET_USER} exists with proper grants"
mysql --connect-timeout=5 ${MYSQL_SSL_MODE:+--ssl-mode=${MYSQL_SSL_MODE}} \
  --protocol=TCP -h "$MYSQL_HOST" -P "$MYSQL_PORT" \
  -u "$MYSQL_LOGIN_USER" -p"$MYSQL_LOGIN_PASSWORD" <<SQL
CREATE USER IF NOT EXISTS '${TARGET_USER}'@'%' IDENTIFIED BY '${TARGET_USER_PASSWORD}';
ALTER USER '${TARGET_USER}'@'%' IDENTIFIED BY '${TARGET_USER_PASSWORD}';
GRANT ALL ON \`${TARGET_DATABASE}\`.* TO '${TARGET_USER}'@'%';
FLUSH PRIVILEGES;
SQL

echo "Verifying connectivity as application user"
mysql --connect-timeout=5 ${MYSQL_SSL_MODE:+--ssl-mode=${MYSQL_SSL_MODE}} \
  --protocol=TCP -h "$MYSQL_HOST" -P "$MYSQL_PORT" \
  -u "$TARGET_USER" -p"$TARGET_USER_PASSWORD" -e "SELECT 1;" "$TARGET_DATABASE" >/dev/null

echo "Database bootstrap completed successfully."
