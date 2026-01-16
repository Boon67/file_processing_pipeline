import { useState } from 'react'
import { useQuery, useMutation } from '@tanstack/react-query'
import { Upload, FileText, CheckCircle, XCircle } from 'lucide-react'
import { bronzeService } from '../services/bronze'
import Card from '../components/Common/Card'
import Button from '../components/Common/Button'
import Alert from '../components/Common/Alert'
import Loading from '../components/Common/Loading'

function UploadFiles() {
  const [selectedFiles, setSelectedFiles] = useState([])
  const [selectedTpa, setSelectedTpa] = useState('')
  const [processImmediately, setProcessImmediately] = useState(true)
  const [uploadResults, setUploadResults] = useState(null)

  // Fetch TPAs
  const { data: tpaData, isLoading: tpasLoading } = useQuery({
    queryKey: ['tpas'],
    queryFn: () => bronzeService.getTpas(true),
  })

  // Upload mutation
  const uploadMutation = useMutation({
    mutationFn: ({ files, tpa, processImmediately }) => 
      bronzeService.uploadFiles(files, tpa, processImmediately),
    onSuccess: (data) => {
      setUploadResults(data)
      setSelectedFiles([])
    },
  })

  const handleFileChange = (e) => {
    const files = Array.from(e.target.files)
    setSelectedFiles(files)
    setUploadResults(null)
  }

  const handleUpload = () => {
    if (!selectedTpa) {
      alert('Please select a TPA')
      return
    }
    
    if (selectedFiles.length === 0) {
      alert('Please select files to upload')
      return
    }

    uploadMutation.mutate({
      files: selectedFiles,
      tpa: selectedTpa,
      processImmediately,
    })
  }

  const formatFileSize = (bytes) => {
    if (bytes === 0) return '0 Bytes'
    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i]
  }

  const validateFile = (file) => {
    const allowedExtensions = ['.csv', '.xlsx', '.xls']
    const ext = '.' + file.name.split('.').pop().toLowerCase()
    
    if (!allowedExtensions.includes(ext)) {
      return { valid: false, message: 'Only CSV and Excel files are allowed' }
    }
    
    if (file.size > 100 * 1024 * 1024) {
      return { valid: false, message: 'File size must be less than 100MB' }
    }
    
    return { valid: true, message: 'Valid' }
  }

  if (tpasLoading) {
    return <Loading text="Loading TPAs..." />
  }

  const tpas = tpaData?.tpas || []
  const selectedTpaObj = tpas.find(t => t.tpa_code === selectedTpa)

  return (
    <div className="max-w-6xl mx-auto space-y-6">
      <div>
        <h2 className="text-3xl font-bold text-gray-900">Upload Files</h2>
        <p className="mt-2 text-gray-600">
          Upload CSV or Excel files to the Bronze layer for processing
        </p>
      </div>

      {/* TPA Selection */}
      <Card title="🏢 Select Third Party Administrator (TPA)">
        <Alert type="info" className="mb-4">
          The TPA determines the subfolder where files will be uploaded. This helps organize files by provider and enables TPA-specific processing rules.
        </Alert>

        {tpas.length === 0 ? (
          <Alert type="error">
            No TPAs found in database. Please contact your administrator to add TPAs to the TPA_MASTER table.
          </Alert>
        ) : (
          <div className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div className="md:col-span-2">
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Select TPA <span className="text-red-500">*</span>
                </label>
                <select
                  value={selectedTpa}
                  onChange={(e) => setSelectedTpa(e.target.value)}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                >
                  <option value="">Choose a TPA...</option>
                  {tpas.map((tpa) => (
                    <option key={tpa.tpa_code} value={tpa.tpa_code}>
                      {tpa.tpa_code} - {tpa.tpa_name}
                    </option>
                  ))}
                </select>
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  TPA Code
                </label>
                <input
                  type="text"
                  value={selectedTpa}
                  disabled
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg bg-gray-50 text-gray-500"
                  placeholder="Select TPA first"
                />
              </div>
            </div>

            {selectedTpaObj?.tpa_description && (
              <p className="text-sm text-gray-600">
                ℹ️ {selectedTpaObj.tpa_description}
              </p>
            )}

            {selectedTpa && (
              <div className="bg-gray-50 p-3 rounded-lg">
                <p className="text-sm font-medium text-gray-700">
                  Target Path: <code className="text-primary-600">@bronze.file_stage/{selectedTpa}/</code>
                </p>
              </div>
            )}
          </div>
        )}
      </Card>

      {/* File Upload */}
      {selectedTpa && (
        <Card title="📁 Select Files">
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Choose CSV or Excel files
              </label>
              <div className="flex items-center justify-center w-full">
                <label className="flex flex-col items-center justify-center w-full h-32 border-2 border-gray-300 border-dashed rounded-lg cursor-pointer bg-gray-50 hover:bg-gray-100">
                  <div className="flex flex-col items-center justify-center pt-5 pb-6">
                    <Upload className="w-10 h-10 mb-3 text-gray-400" />
                    <p className="mb-2 text-sm text-gray-500">
                      <span className="font-semibold">Click to upload</span> or drag and drop
                    </p>
                    <p className="text-xs text-gray-500">CSV, XLSX, or XLS files (max 100MB)</p>
                  </div>
                  <input
                    type="file"
                    multiple
                    accept=".csv,.xlsx,.xls"
                    onChange={handleFileChange}
                    className="hidden"
                  />
                </label>
              </div>
            </div>

            {/* Selected Files */}
            {selectedFiles.length > 0 && (
              <div className="space-y-2">
                <p className="text-sm font-medium text-gray-700">
                  📎 {selectedFiles.length} file(s) selected
                </p>
                
                <div className="border border-gray-200 rounded-lg divide-y">
                  {selectedFiles.map((file, index) => {
                    const validation = validateFile(file)
                    return (
                      <div key={index} className="p-3 flex items-center justify-between">
                        <div className="flex items-center space-x-3 flex-1">
                          <FileText className="w-5 h-5 text-gray-400" />
                          <div className="flex-1">
                            <p className="text-sm font-medium text-gray-900">{file.name}</p>
                            <p className="text-xs text-gray-500">Size: {formatFileSize(file.size)}</p>
                          </div>
                        </div>
                        <div>
                          {validation.valid ? (
                            <CheckCircle className="w-5 h-5 text-green-500" />
                          ) : (
                            <div className="flex items-center space-x-2">
                              <XCircle className="w-5 h-5 text-red-500" />
                              <span className="text-xs text-red-600">{validation.message}</span>
                            </div>
                          )}
                        </div>
                      </div>
                    )
                  })}
                </div>
              </div>
            )}

            {/* Process Immediately Option */}
            <div className="border-t pt-4">
              <label className="flex items-center space-x-3 cursor-pointer">
                <input
                  type="checkbox"
                  checked={processImmediately}
                  onChange={(e) => setProcessImmediately(e.target.checked)}
                  className="w-4 h-4 text-primary-600 border-gray-300 rounded focus:ring-primary-500"
                />
                <span className="text-sm font-medium text-gray-700">
                  🚀 Process Files Immediately
                </span>
              </label>
              <p className="ml-7 mt-1 text-xs text-gray-500">
                {processImmediately
                  ? '✓ Files will be processed immediately after upload'
                  : '⏰ Files will be processed on next scheduled run'}
              </p>
            </div>

            {/* Upload Button */}
            <Button
              variant="primary"
              size="lg"
              onClick={handleUpload}
              loading={uploadMutation.isPending}
              disabled={selectedFiles.length === 0 || !selectedTpa}
              className="w-full"
            >
              <Upload className="w-5 h-5 mr-2" />
              Upload to Snowflake
            </Button>
          </div>
        </Card>
      )}

      {/* Upload Results */}
      {uploadResults && (
        <Card title="Upload Results">
          <div className="space-y-4">
            {uploadMutation.isError && (
              <Alert type="error">
                {uploadMutation.error?.message || 'Upload failed'}
              </Alert>
            )}

            {uploadMutation.isSuccess && (
              <>
                <div className="grid grid-cols-3 gap-4">
                  <div className="bg-gray-50 p-4 rounded-lg">
                    <p className="text-sm text-gray-600">Total Files</p>
                    <p className="text-2xl font-bold text-gray-900">
                      {uploadResults.files?.length || 0}
                    </p>
                  </div>
                  <div className="bg-green-50 p-4 rounded-lg">
                    <p className="text-sm text-green-600">Successful</p>
                    <p className="text-2xl font-bold text-green-900">
                      {uploadResults.files?.filter(f => f.status === 'uploaded').length || 0}
                    </p>
                  </div>
                  <div className="bg-red-50 p-4 rounded-lg">
                    <p className="text-sm text-red-600">Failed</p>
                    <p className="text-2xl font-bold text-red-900">
                      {uploadResults.files?.filter(f => f.status === 'failed').length || 0}
                    </p>
                  </div>
                </div>

                <Alert type="success">
                  🎉 Successfully uploaded {uploadResults.files?.filter(f => f.status === 'uploaded').length || 0} file(s)!
                  {processImmediately && (
                    <p className="mt-2">🎯 Files are now being discovered and will be processed shortly</p>
                  )}
                </Alert>

                <div className="border border-gray-200 rounded-lg divide-y">
                  {uploadResults.files?.map((file, index) => (
                    <div key={index} className="p-3 flex items-center justify-between">
                      <div className="flex items-center space-x-3">
                        <FileText className="w-5 h-5 text-gray-400" />
                        <div>
                          <p className="text-sm font-medium text-gray-900">{file.originalName}</p>
                          <p className="text-xs text-gray-500">TPA: {file.tpa}</p>
                        </div>
                      </div>
                      <div>
                        {file.status === 'uploaded' ? (
                          <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                            <CheckCircle className="w-4 h-4 mr-1" />
                            Uploaded
                          </span>
                        ) : (
                          <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
                            <XCircle className="w-4 h-4 mr-1" />
                            Failed
                          </span>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              </>
            )}
          </div>
        </Card>
      )}
    </div>
  )
}

export default UploadFiles
