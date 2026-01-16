import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { FolderOpen, RefreshCw } from 'lucide-react'
import { bronzeService } from '../services/bronze'
import Card from '../components/Common/Card'
import Button from '../components/Common/Button'
import Loading from '../components/Common/Loading'

function FileStages() {
  const [selectedStage, setSelectedStage] = useState('file_stage')

  const stages = [
    { value: 'file_stage', label: 'File Stage (Source)' },
    { value: 'error_stage', label: 'Error Stage' },
    { value: 'archive_stage', label: 'Archive Stage' },
  ]

  const { data, isLoading, refetch } = useQuery({
    queryKey: ['stages', selectedStage],
    queryFn: () => bronzeService.getStageFiles(selectedStage),
  })

  const files = data?.files || []

  const formatFileSize = (bytes) => {
    if (!bytes) return 'N/A'
    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i]
  }

  return (
    <div className="max-w-7xl mx-auto space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-bold text-gray-900">File Stages</h2>
          <p className="mt-2 text-gray-600">
            Browse files across different stages in the pipeline
          </p>
        </div>
        <Button onClick={refetch} variant="secondary">
          <RefreshCw className="w-4 h-4 mr-2" />
          Refresh
        </Button>
      </div>

      {/* Stage Selection */}
      <Card>
        <div className="flex items-center space-x-4">
          <label className="text-sm font-medium text-gray-700">
            Select Stage:
          </label>
          <div className="flex space-x-2">
            {stages.map(stage => (
              <button
                key={stage.value}
                onClick={() => setSelectedStage(stage.value)}
                className={`px-4 py-2 text-sm font-medium rounded-lg transition-colors ${
                  selectedStage === stage.value
                    ? 'bg-primary-600 text-white'
                    : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                }`}
              >
                {stage.label}
              </button>
            ))}
          </div>
        </div>
      </Card>

      {/* Files List */}
      <Card title={`Files in ${stages.find(s => s.value === selectedStage)?.label}`}>
        {isLoading ? (
          <Loading text="Loading files..." />
        ) : (
          <div className="space-y-4">
            <p className="text-sm text-gray-600">
              Found {files.length} file(s)
            </p>

            {files.length === 0 ? (
              <div className="text-center py-12">
                <FolderOpen className="w-12 h-12 text-gray-400 mx-auto mb-4" />
                <p className="text-gray-500">No files in this stage</p>
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="min-w-full divide-y divide-gray-200">
                  <thead className="bg-gray-50">
                    <tr>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        File Name
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Size
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Last Modified
                      </th>
                    </tr>
                  </thead>
                  <tbody className="bg-white divide-y divide-gray-200">
                    {files.map((file, index) => (
                      <tr key={index} className="hover:bg-gray-50">
                        <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                          {file.name}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                          {formatFileSize(file.size)}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                          {file.last_modified || 'N/A'}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        )}
      </Card>
    </div>
  )
}

export default FileStages
