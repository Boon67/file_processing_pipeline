import api from './api'

export const bronzeService = {
  // Get list of TPAs
  getTpas: async (activeOnly = true) => {
    return api.get('/tpas', {
      params: { active_only: activeOnly }
    })
  },

  // Upload files
  uploadFiles: async (files, tpa, processImmediately = true) => {
    const formData = new FormData()
    
    files.forEach(file => {
      formData.append('files', file)
    })
    
    formData.append('tpa', tpa)
    formData.append('process_immediately', processImmediately)
    
    return api.post('/bronze/upload', formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    })
  },

  // Get files in processing queue
  getFiles: async (params = {}) => {
    return api.get('/bronze/files', { params })
  },

  // Get processing summary
  getSummary: async () => {
    return api.get('/bronze/summary')
  },

  // Get files in stages
  getStageFiles: async (stage = 'file_stage') => {
    return api.get('/bronze/stages', {
      params: { stage }
    })
  },

  // Get raw data
  getRawData: async (params = {}) => {
    return api.get('/bronze/raw-data', { params })
  },

  // Get tasks
  getTasks: async () => {
    return api.get('/bronze/tasks')
  },

  // Execute task
  executeTask: async (taskName) => {
    return api.post(`/bronze/tasks/${taskName}/execute`)
  },

  // Get processing statistics
  getStats: async () => {
    return api.get('/bronze/summary')
  },
}

export default bronzeService
