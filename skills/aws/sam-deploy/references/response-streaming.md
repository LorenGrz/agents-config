# Lambda response streaming (Node.js)

Read when: a response must be streamed through API Gateway (large or incremental payloads).

```js
// Must use InvokeWithResponseStream — configure in template.yaml
// `awslambda` is a global provided by the Node.js Lambda runtime: do not import it.

export const handler = awslambda.streamifyResponse(async (event, responseStream, context) => {
  const metadata = { statusCode: 200, headers: { 'Content-Type': 'text/html' } }
  responseStream = awslambda.HttpResponseStream.from(responseStream, metadata)
  responseStream.write('chunk 1')
  responseStream.write('chunk 2')
  responseStream.end()
})
```

API Gateway method must set `ResponseTransferMode: STREAM` in the integration. Only REST APIs support it; HTTP APIs do not.
