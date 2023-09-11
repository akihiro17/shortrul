{
  "family": "api",
  "containerDefinitions": [
      {
          "name": "api",
          "image": "${ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/api:latest",
          "cpu": 256,
          "memory": 128,
          "portMappings": [
              {
                  "containerPort": 80,
                  "hostPort": 80,
                  "protocol": "tcp"
              }
          ],
          "essential": true,
          "environment": [
            {
                "name": "MYSQL_HOST",
                "value": "${MYSQL_HOST}"
            },
            {
                "name": "MYSQL_PASSWORD",
                "value": "${MYSQL_PASSWORD}"
            },
            {
                "name": "LISTEN_PORT",
                "value": "80"
            }
          ],
          "mountPoints": [],
          "volumesFrom": [],
          "logConfiguration": {
              "logDriver": "awslogs",
              "options": {
                  "awslogs-group": "/ecs/logs/test/api",
                  "awslogs-region": "ap-northeast-1",
                  "awslogs-stream-prefix": "api"
              }
          }
      }
  ],
  "executionRoleArn": "arn:aws:iam::363188159740:role/ecsTaskExecutionRole",
  "networkMode": "awsvpc",
  "requiresCompatibilities": [
      "FARGATE"
  ],
  "cpu": "256",
  "memory": "512"
}
