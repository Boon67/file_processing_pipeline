import api from './api'

export const systemService = {
  // Get system configuration
  getConfig: async () => {
    return api.get('/config')
  },

  // Get system statistics
  getStats: async () => {
    return api.get('/stats')
  },

  // Health check
  healthCheck: async () => {
    return api.get('/health')
  },
}

export default systemService
