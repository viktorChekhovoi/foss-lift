// The same request handler runs in Pages Functions and the integration runtime.
import { handleRequest } from './api.js';
export default { fetch: handleRequest };
