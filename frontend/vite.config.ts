import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      // Browser calls same-origin '/api/login', Vite forwards it to FastAPI
      // as 'http://localhost:8000/login'. Keeps the frontend free of any
      // hardcoded backend URL/port, and sidesteps CORS entirely in dev.
      '/api': {
        target: 'http://localhost:8000',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, ''),
      },
    },
  },
})
