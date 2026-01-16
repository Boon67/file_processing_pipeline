import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { RefreshCw, Download } from 'lucide-react'
import { bronzeService } from '../services/bronze'
import Card from '../components/Common/Card'
import Button from '../components/Common/Button'
import Loading from '../components/Common/Loading'
import { format } from 'date-fns'

function ProcessingStatus() {
  const [statusFilter, setStatusFilter] = useState(['SUCCESS', 'FAILED', 'PROCESSING', 'PENDING'])
  const [fileTypeFilter, setFileTypeFilter] = useState(['CSV', 'EXCEL'])
  const [tpaFilter, setTpaFilter] = useState([])

  // Fetch files
  const { data: filesData, isLoading, refetch } = useQuery({
    queryKey: ['files'],
    queryFn: () => bronzeService.getFiles(),
    refetchInterval: 30000, // Auto-refresh every 30 seconds
  })

  // Fetch summary stats
  const { data: summaryData } = useQuery({
    queryKey: ['summary'],
    queryFn: () => bronzeService.getSummary(),
    refetchInterval: 30000,
  })

  const files = filesData?.files || []
  const summary = summaryData?.files || {}
  const rawData = summaryData?.rawData || {}

  // Get unique TPAs from files
  const uniqueTpas = [...new Set(files.map(f => f.tpa).filter(Boolean))].sort()
  
  // Initialize TPA filter with all TPAs
  if (tpaFilter.length === 0 && uniqueTpas.length > 0) {
    setTpaFilter(uniqueTpas)
  }

  // Apply filters
  const filteredFiles = files.filter(file => {
    const statusMatch = statusFilter.includes(file.status)
    const typeMatch = fileTypeFilter.includes(file.file_type)
    const tpaMatch = !file.tpa || tpaFilter.includes(file.tpa)
    return statusMatch && typeMatch && tpaMatch
  })

  const handleRefresh = () => {
    refetch()
  }

  const handleDownloadCSV = () => {
    const headers = ['File Name', 'Type', 'TPA', 'Status', 'Discovered', 'Processed', 'Result', 'Error']
    const rows = filteredFiles.map(file => [
      file.file_name,
      file.file_type,
      file.tpa || 'N/A',
      file.status,
      file.created_timestamp ? format(new Date(file.created_timestamp), 'yyyy-MM-dd HH:mm:ss') : '',
      file.processed_timestamp ? format(new Date(file.processed_timestamp), 'yyyy-MM-dd HH:mm:ss') : '',
      file.process_result || '',
      file.error_message || '',
    ])

    const csv = [headers, ...rows].map(row => row.map(cell => `"${cell}"`).join(',')).join('\n')
    const blob = new Blob([csv], { type: 'text/csv' })
    const url = window.URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `processed_files_${format(new Date(), 'yyyyMMdd_HHmmss')}.csv`
    a.click()
    window.URL.revokeObjectURL(url)
  }

  const getStatusEmoji = (status) => {
    const emojis = {
      'SUCCESS': '✅',
      'FAILED': '❌',
      'PROCESSING': '⏳',
      'PENDING': '⏸️',
    }
    return emojis[status] || ''
  }

  const getStatusColor = (status) => {
    const colors = {
      'SUCCESS': 'bg-green-100 text-green-800',
      'FAILED': 'bg-red-100 text-red-800',
      'PROCESSING': 'bg-blue-100 text-blue-800',
      'PENDING': 'bg-gray-100 text-gray-800',
    }
    return colors[status] || 'bg-gray-100 text-gray-800'
  }

  if (isLoading) {
    return <Loading text="Loading processing status..." />
  }

  const totalFiles = summary.total_files || 0
  const successfulFiles = summary.completed_files || 0
  const failedFiles = summary.failed_files || 0
  const processingFiles = summary.processing_files || 0
  const totalRows = rawData.total_records || 0

  return (
    <div className="max-w-7xl mx-auto space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-bold text-gray-900">Processing Status</h2>
          <p className="mt-2 text-gray-600">
            View all files that have been processed through the pipeline with their status and statistics
          </p>
        </div>
        <Button onClick={handleRefresh} variant="secondary">
          <RefreshCw className="w-4 h-4 mr-2" />
          Refresh Now
        </Button>
      </div>

      {/* Summary Metrics */}
      <div className="grid grid-cols-1 md:grid-cols-5 gap-4">
        <Card className="p-4">
          <div className="text-center">
            <p className="text-sm text-gray-600">Total Files</p>
            <p className="text-3xl font-bold text-gray-900 mt-2">{totalFiles}</p>
          </div>
        </Card>
        
        <Card className="p-4">
          <div className="text-center">
            <p className="text-sm text-gray-600">✅ Success</p>
            <p className="text-3xl font-bold text-green-600 mt-2">{successfulFiles}</p>
            {totalFiles > 0 && (
              <p className="text-xs text-gray-500 mt-1">
                {((successfulFiles / totalFiles) * 100).toFixed(1)}%
              </p>
            )}
          </div>
        </Card>
        
        <Card className="p-4">
          <div className="text-center">
            <p className="text-sm text-gray-600">❌ Failed</p>
            <p className="text-3xl font-bold text-red-600 mt-2">{failedFiles}</p>
            {totalFiles > 0 && (
              <p className="text-xs text-gray-500 mt-1">
                {((failedFiles / totalFiles) * 100).toFixed(1)}%
              </p>
            )}
          </div>
        </Card>
        
        <Card className="p-4">
          <div className="text-center">
            <p className="text-sm text-gray-600">⏳ Processing</p>
            <p className="text-3xl font-bold text-blue-600 mt-2">{processingFiles}</p>
          </div>
        </Card>
        
        <Card className="p-4">
          <div className="text-center">
            <p className="text-sm text-gray-600">📊 Total Rows</p>
            <p className="text-3xl font-bold text-gray-900 mt-2">
              {totalRows.toLocaleString()}
            </p>
          </div>
        </Card>
      </div>

      {/* Filters */}
      <Card title="Filters">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {/* Status Filter */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Filter by Status
            </label>
            <div className="space-y-2">
              {['SUCCESS', 'FAILED', 'PROCESSING', 'PENDING'].map(status => (
                <label key={status} className="flex items-center">
                  <input
                    type="checkbox"
                    checked={statusFilter.includes(status)}
                    onChange={(e) => {
                      if (e.target.checked) {
                        setStatusFilter([...statusFilter, status])
                      } else {
                        setStatusFilter(statusFilter.filter(s => s !== status))
                      }
                    }}
                    className="w-4 h-4 text-primary-600 border-gray-300 rounded focus:ring-primary-500"
                  />
                  <span className="ml-2 text-sm text-gray-700">
                    {getStatusEmoji(status)} {status}
                  </span>
                </label>
              ))}
            </div>
          </div>

          {/* File Type Filter */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Filter by File Type
            </label>
            <div className="space-y-2">
              {['CSV', 'EXCEL'].map(type => (
                <label key={type} className="flex items-center">
                  <input
                    type="checkbox"
                    checked={fileTypeFilter.includes(type)}
                    onChange={(e) => {
                      if (e.target.checked) {
                        setFileTypeFilter([...fileTypeFilter, type])
                      } else {
                        setFileTypeFilter(fileTypeFilter.filter(t => t !== type))
                      }
                    }}
                    className="w-4 h-4 text-primary-600 border-gray-300 rounded focus:ring-primary-500"
                  />
                  <span className="ml-2 text-sm text-gray-700">{type}</span>
                </label>
              ))}
            </div>
          </div>

          {/* TPA Filter */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Filter by TPA
            </label>
            <div className="space-y-2 max-h-32 overflow-y-auto">
              {uniqueTpas.map(tpa => (
                <label key={tpa} className="flex items-center">
                  <input
                    type="checkbox"
                    checked={tpaFilter.includes(tpa)}
                    onChange={(e) => {
                      if (e.target.checked) {
                        setTpaFilter([...tpaFilter, tpa])
                      } else {
                        setTpaFilter(tpaFilter.filter(t => t !== tpa))
                      }
                    }}
                    className="w-4 h-4 text-primary-600 border-gray-300 rounded focus:ring-primary-500"
                  />
                  <span className="ml-2 text-sm text-gray-700">{tpa}</span>
                </label>
              ))}
            </div>
          </div>
        </div>
      </Card>

      {/* Files Table */}
      <Card>
        <div className="flex items-center justify-between mb-4">
          <p className="text-sm font-medium text-gray-700">
            Showing {filteredFiles.length} files
          </p>
          <Button onClick={handleDownloadCSV} variant="secondary" size="sm">
            <Download className="w-4 h-4 mr-2" />
            Download CSV
          </Button>
        </div>

        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  File Name
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Type
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  TPA
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Status
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Discovered
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Processed
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Records
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {filteredFiles.length === 0 ? (
                <tr>
                  <td colSpan="7" className="px-6 py-4 text-center text-sm text-gray-500">
                    No files found
                  </td>
                </tr>
              ) : (
                filteredFiles.map((file, index) => (
                  <tr key={index} className="hover:bg-gray-50">
                    <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                      {file.file_name}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {file.file_type}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {file.tpa || 'N/A'}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getStatusColor(file.status)}`}>
                        {getStatusEmoji(file.status)} {file.status}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {file.created_timestamp 
                        ? format(new Date(file.created_timestamp), 'yyyy-MM-dd HH:mm:ss')
                        : '-'}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {file.processed_timestamp 
                        ? format(new Date(file.processed_timestamp), 'yyyy-MM-dd HH:mm:ss')
                        : '-'}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {file.record_count ? file.record_count.toLocaleString() : '-'}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </Card>
    </div>
  )
}

export default ProcessingStatus
