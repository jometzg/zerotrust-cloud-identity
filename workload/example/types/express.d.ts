import 'express';

declare global {
  namespace Express {
    interface User {
      id: string;
      name?: string;
      roles?: string[];
      scope?: string;
    }
  }
}

declare module 'express-serve-static-core' {
  interface Request {
    user?: {
      id: string;
      name?: string;
      roles?: string[];
      scope?: string;
      [key: string]: any;
    };
  }
}
