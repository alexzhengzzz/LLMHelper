# Javis API Reference Documentation

## Overview

Javis provides a comprehensive REST API and WebSocket interface for AI-powered programming assistance. This document provides detailed specifications for all available endpoints, request/response formats, and usage examples.

## Base URLs

### Production Environment
- **REST API**: `http://xx.xx.xx.xx:8080/api`
- **WebSocket**: `ws://xx.xx.xx.xx:8080/ws`

### Development Environment
- **REST API**: `http://localhost:8080/api`
- **WebSocket**: `ws://localhost:8080/ws`

## Authentication

Currently, the API uses open access with rate limiting. Future versions will include API key authentication.

## REST API Endpoints

### 1. Chat Completion

#### POST `/api/chat`

Initiate a conversation with an AI model.

**Request Body:**
```json
{
  "model": "string",
  "messages": [
    {
      "role": "system" | "user" | "assistant",
      "content": "string"
    }
  ],
  "stream": boolean,
  "temperature": number,
  "max_tokens": number,
  "tools": array,
  "tool_choice": "auto" | "none" | object
}
```

**Parameters:**
- `model` (required): AI model identifier in format `provider.model_name`
  - Examples: `siliconflow.Qwen/Qwen2.5-7B-Instruct`, `google.gemini-1.5-flash`, `zhipu.glm-4`
- `messages` (required): Array of conversation messages
- `stream` (optional, default: false): Enable streaming response
- `temperature` (optional, default: 0.7): Sampling temperature (0.0-2.0)
- `max_tokens` (optional): Maximum response tokens
- `tools` (optional): Array of available tools for function calling
- `tool_choice` (optional): How to use tools

**Response:**
```json
{
  "id": "string",
  "object": "chat.completion",
  "created": timestamp,
  "model": "string",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "string",
        "tool_calls": array
      },
      "finish_reason": "stop" | "length" | "tool_calls"
    }
  ],
  "usage": {
    "prompt_tokens": number,
    "completion_tokens": number,
    "total_tokens": number
  }
}
```

**Status Codes:**
- `200`: Success
- `400`: Bad request (invalid parameters)
- `401`: Unauthorized
- `429`: Rate limit exceeded
- `500`: Internal server error

**Example Request:**
```bash
curl -X POST http://xx.xx.xx.xx:8080/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model": "siliconflow.Qwen/Qwen2.5-7B-Instruct",
    "messages": [
      {
        "role": "user",
        "content": "Write a Python function to calculate fibonacci numbers"
      }
    ]
  }'
```

---

### 2. Code Execution

#### POST `/api/execute`

Execute code in a secure sandbox environment.

**Request Body:**
```json
{
  "language": "python" | "javascript" | "go" | "bash",
  "code": "string",
  "timeout": number
}
```

**Parameters:**
- `language` (required): Programming language
- `code` (required): Source code to execute
- `timeout` (optional, default: 30): Execution timeout in seconds

**Response:**
```json
{
  "success": boolean,
  "output": "string",
  "error": "string",
  "execution_time": number,
  "language": "string"
}
```

**Status Codes:**
- `200`: Success
- `400`: Invalid language or code
- `408`: Execution timeout
- `422`: Code execution error
- `500`: Internal server error

**Example Request:**
```bash
curl -X POST http://xx.xx.xx.xx:8080/api/execute \
  -H "Content-Type: application/json" \
  -d '{
    "language": "python",
    "code": "print('Hello, World!')",
    "timeout": 10
  }'
```

---

### 3. Web Search

#### POST `/api/search`

Perform web searches to get current information.

**Request Body:**
```json
{
  "query": "string",
  "provider": "google" | "bing" | "duckduckgo",
  "max_results": number
}
```

**Parameters:**
- `query` (required): Search query
- `provider` (optional, default: "google"): Search provider
- `max_results` (optional, default: 5): Maximum number of results

**Response:**
```json
{
  "query": "string",
  "results": [
    {
      "title": "string",
      "url": "string",
      "snippet": "string",
      "source": "string"
    }
  ],
  "total_results": number,
  "search_time": number
}
```

**Status Codes:**
- `200`: Success
- `400`: Invalid query
- `429`: Search rate limit exceeded
- `500`: Internal server error

**Example Request:**
```bash
curl -X POST http://xx.xx.xx.xx:8080/api/search \
  -H "Content-Type: application/json" \
  -d '{
    "query": "HarmonyOS ArkTS development",
    "max_results": 3
  }'
```

---

### 4. Get Available Models

#### GET `/api/providers`

Retrieve list of available AI models and providers.

**Response:**
```json
{
  "providers": [
    {
      "name": "string",
      "display_name": "string",
      "models": [
        {
          "id": "string",
          "name": "string",
          "description": "string",
          "capabilities": array,
          "context_window": number,
          "supports_streaming": boolean,
          "supports_tools": boolean
        }
      ]
    }
  ]
}
```

**Status Codes:**
- `200`: Success
- `500`: Internal server error

**Example Request:**
```bash
curl -X GET http://xx.xx.xx.xx:8080/api/providers
```

---

### 5. Get Search Providers

#### GET `/api/search/providers`

Retrieve list of available search providers.

**Response:**
```json
{
  "providers": [
    {
      "name": "string",
      "display_name": "string",
      "enabled": boolean,
      "rate_limit": {
        "requests_per_minute": number,
        "requests_per_hour": number
      }
    }
  ]
}
```

**Status Codes:**
- `200`: Success
- `500`: Internal server error

**Example Request:**
```bash
curl -X GET http://xx.xx.xx.xx:8080/api/search/providers
```

---

### 6. Usage Statistics

#### GET `/api/usage/stats`

Retrieve API usage statistics and limits.

**Response:**
```json
{
  "total_requests": number,
  "requests_today": number,
  "requests_this_month": number,
  "daily_limit": number,
  "monthly_limit": number,
  "reset_time": "timestamp",
  "usage_by_provider": {
    "provider_name": {
      "requests": number,
      "tokens_used": number,
      "cost": number
    }
  },
  "usage_by_model": {
    "model_name": {
      "requests": number,
      "tokens_used": number
    }
  }
}
```

**Status Codes:**
- `200`: Success
- `401**: Unauthorized
- `500**: Internal server error

**Example Request:**
```bash
curl -X GET http://xx.xx.xx.xx:8080/api/usage/stats
```

---

### 7. Update Usage Limit

#### PUT `/api/usage/limit`

Update daily or monthly usage limits.

**Request Body:**
```json
{
  "daily_limit": number,
  "monthly_limit": number
}
```

**Parameters:**
- `daily_limit` (optional): Maximum requests per day
- `monthly_limit` (optional): Maximum requests per month

**Response:**
```json
{
  "success": boolean,
  "message": "string",
  "updated_limits": {
    "daily_limit": number,
    "monthly_limit": number
  }
}
```

**Status Codes:**
- `200`: Success
- `400**: Invalid limits
- `401**: Unauthorized
- `500**: Internal server error

**Example Request:**
```bash
curl -X PUT http://xx.xx.xx.xx:8080/api/usage/limit \
  -H "Content-Type: application/json" \
  -d '{
    "daily_limit": 1000,
    "monthly_limit": 30000
  }'
```

---

## WebSocket API

### Connection

#### Connect to WebSocket

```javascript
const ws = new WebSocket('ws://xx.xx.xx.xx:8080/ws');
```

### Message Format

#### Client to Server Messages

**Chat Request:**
```json
{
  "type": "chat",
  "id": "string",
  "model": "string",
  "messages": array,
  "stream": true
}
```

**Status Request:**
```json
{
  "type": "status",
  "id": "string"
}
```

#### Server to Client Messages

**Stream Response:**
```json
{
  "type": "chat_chunk",
  "id": "string",
  "content": "string",
  "done": boolean
}
```

**Status Response:**
```json
{
  "type": "status",
  "id": "string",
  "status": "connected" | "processing" | "completed" | "error",
  "message": "string"
}
```

### Error Handling

#### WebSocket Error Codes

- `1000`: Normal closure
- `1001`: Going away
- `1002`: Protocol error
- `1003`: Unsupported data
- `1005`: No status code
- `1006`: Abnormal closure
- `1007`: Invalid frame payload data
- `1008**: Policy violation
- `1009**: Message too big
- `1010**: Missing extension
- `1011**: Internal error
- `1012**: Service restart
- `1013**: Try again later
- `1014**: Bad gateway
- `1015**: TLS handshake failure

### JavaScript Example

```javascript
// Initialize WebSocket connection
const ws = new WebSocket('ws://xx.xx.xx.xx:8080/ws');

ws.onopen = () => {
  console.log('Connected to Javis WebSocket');

  // Send chat request
  ws.send(JSON.stringify({
    type: 'chat',
    id: 'chat_123',
    model: 'siliconflow.Qwen/Qwen2.5-7B-Instruct',
    messages: [
      {
        role: 'user',
        content: 'Hello, how are you?'
      }
    ],
    stream: true
  }));
};

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);

  switch (data.type) {
    case 'chat_chunk':
      console.log('Received chunk:', data.content);
      if (data.done) {
        console.log('Stream completed');
      }
      break;
    case 'status':
      console.log('Status update:', data.status, data.message);
      break;
    default:
      console.log('Unknown message type:', data.type);
  }
};

ws.onerror = (error) => {
  console.error('WebSocket error:', error);
};

ws.onclose = (event) => {
  console.log('WebSocket closed:', event.code, event.reason);
};
```

---

## Error Handling

### Common Error Responses

**Rate Limiting:**
```json
{
  "error": {
    "type": "rate_limit_exceeded",
    "message": "API rate limit exceeded",
    "code": 429,
    "retry_after": 60
  }
}
```

**Invalid Model:**
```json
{
  "error": {
    "type": "invalid_model",
    "message": "Model not found: invalid_model",
    "code": 400,
    "available_models": ["model1", "model2", "model3"]
  }
}
```

**Authentication Error:**
```json
{
  "error": {
    "type": "authentication_error",
    "message": "Invalid API key",
    "code": 401
  }
}
```

**Server Error:**
```json
{
  "error": {
    "type": "server_error",
    "message": "Internal server error",
    "code": 500
  }
}
```

### Error Recovery

1. **Rate Limiting**: Implement exponential backoff
2. **Network Errors**: Implement retry logic with jitter
3. **Invalid Input**: Validate requests before sending
4. **Server Errors**: Implement circuit breaker pattern

---

## Rate Limiting

### Current Limits

- **Chat API**: 100 requests per minute
- **Code Execution**: 50 requests per minute
- **Web Search**: 30 requests per minute
- **WebSocket**: 100 concurrent connections

### Rate Limit Headers

All API responses include rate limiting headers:

```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1640995200
X-RateLimit-Window: 60
```

---

## Best Practices

### Request Optimization

1. **Batch Requests**: Combine multiple messages in a single request
2. **Streaming**: Use streaming for long responses
3. **Caching**: Cache model lists and provider information
4. **Connection Pooling**: Reuse HTTP connections

### Error Handling

1. **Retry Logic**: Implement exponential backoff for transient errors
2. **Fallback Models**: Have backup models for high-priority requests
3. **Graceful Degradation**: Handle API failures gracefully
4. **User Feedback**: Provide clear error messages to users

### Security

1. **Input Validation**: Sanitize all user inputs
2. **Code Execution**: Use sandboxed environments
3. **API Keys**: Store API keys securely (client-side only)
4. **Rate Limiting**: Respect rate limits to avoid service disruption

---

## Troubleshooting

### Common Issues

**Connection Timeouts**
- Check network connectivity
- Verify server status
- Increase timeout values

**Authentication Errors**
- Verify API endpoint
- Check for correct headers
- Ensure API keys are valid

**Rate Limiting**
- Implement backoff strategies
- Use caching for static data
- Optimize request frequency

**Code Execution Failures**
- Validate code syntax
- Check language support
- Handle timeout gracefully

### Debug Information

Enable debug mode by setting the `X-Debug: true` header to receive detailed error information and performance metrics.

### Support

For API support and issues:
- Check the [GitHub Issues](https://github.com/your-repo/issues)
- Review the [troubleshooting guide](./TROUBLESHOOTING.md)
- Contact the development team