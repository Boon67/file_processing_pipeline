import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Database, RefreshCw, ChevronLeft, ChevronRight } from 'lucide-react'
import { bronzeService } from '../services/bronze'
import Card from '../components/Common/Card'
import Button from '../components/Common/Button'
import Loading from '../components/Common/Loading'

function RawDataViewer() {
  const [tpaFilter, setTpaFilter] = useState('')
  const [limit, setLimit] = useState(100)
  const [offset, setOffset] = useState(0)

  const { data, isLoading, refetch } = useQuery({
    queryKey: ['rawData', tpaFilter, limit, offset],
    queryFn: () => bronzeService.getRawData({ 
      tpa: tpaFilter || undefined, 
      limit, 
      offset 
    }),
  })

  const { data: tpaData } = useQuery({
    queryKey: ['tpas'],
    queryFn: () => bronzeService.getTpas(true),
  })

  const rows = data?.data || []
  const summary = data?.summary || {}
  const tpas = tpaData?.tpas || []

  const handlePrevious = () => {
    if (offset > 0) {
      setOffset(Math.max(0, offset - limit))
    }
  }

  const handleNext = () => {
    setOffset(offset + limit)
  }

  return (
    <div className="max-w-7xl mx-auto space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-bold text-gray-900">Raw Data Viewer</h2>
          <p className="mt-2 text-gray-600">
            View and filter raw data from the Bronze layer
          </p>
        </div>
        <Button onClick={refetch} variant="secondary">
          <RefreshCw className="w-4 h-4 mr-2" />
          Refresh
        </Button>
      </div>

      {/* Summary Stats */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <Card className="p-4">
          <div className="text-center">
            <p className="text-sm text-gray-600">Total Rows</p>
            <p className="text-3xl font-bold text-gray-900 mt-2">
              {(summary.total_rows || 0).toLocaleString()}
            </p>
          </div>
        </Card>
        
        <Card className="p-4">
          <div className="text-center">
            <p className="text-sm text-gray-600">Total TPAs</p>
            <p className="text-3xl font-bold text-primary-600 mt-2">
              {summary.total_tpas || 0}
            </p>
          </div>
        </Card>
        
        <Card className="p-4">
          <div className="text-center">
            <p className="text-sm text-gray-600">Total Files</p>
            <p className="text-3xl font-bold text-gray-900 mt-2">
              {summary.total_files || 0}
            </p>
          </div>
        </Card>
      </div>

      {/* Filters */}
      <Card title="Filters">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Filter by TPA
            </label>
            <select
              value={tpaFilter}
              onChange={(e) => {
                setTpaFilter(e.target.value)
                setOffset(0)
              }}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
            >
              <option value="">All TPAs</option>
              {tpas.map((tpa) => (
                <option key={tpa.tpa_code} value={tpa.tpa_code}>
                  {tpa.tpa_code} - {tpa.tpa_name}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Rows per page
            </label>
            <select
              value={limit}
              onChange={(e) => {
                setLimit(Number(e.target.value))
                setOffset(0)
              }}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
            >
              <option value="50">50</option>
              <option value="100">100</option>
              <option value="200">200</option>
              <option value="500">500</option>
            </select>
          </div>

          <div className="flex items-end">
            <div className="flex space-x-2 w-full">
              <Button 
                onClick={handlePrevious} 
                disabled={offset === 0}
                variant="secondary"
                className="flex-1"
              >
                <ChevronLeft className="w-4 h-4 mr-1" />
                Previous
              </Button>
              <Button 
                onClick={handleNext}
                disabled={rows.length < limit}
                variant="secondary"
                className="flex-1"
              >
                Next
                <ChevronRight className="w-4 h-4 ml-1" />
              </Button>
            </div>
          </div>
        </div>
      </Card>

      {/* Data Table */}
      <Card>
        {isLoading ? (
          <Loading text="Loading data..." />
        ) : (
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <p className="text-sm text-gray-600">
                Showing rows {offset + 1} - {offset + rows.length} of {(summary.total_rows || 0).toLocaleString()}
              </p>
            </div>

            {rows.length === 0 ? (
              <div className="text-center py-12">
                <Database className="w-12 h-12 text-gray-400 mx-auto mb-4" />
                <p className="text-gray-500">No data found</p>
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="min-w-full divide-y divide-gray-200">
                  <thead className="bg-gray-50">
                    <tr>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        File ID
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Row Number
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        TPA
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Data
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Created
                      </th>
                    </tr>
                  </thead>
                  <tbody className="bg-white divide-y divide-gray-200">
                    {rows.map((row, index) => (
                      <tr key={index} className="hover:bg-gray-50">
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                          {row.file_id}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                          {row.row_number}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                          {row.tpa}
                        </td>
                        <td className="px-6 py-4 text-sm text-gray-500 max-w-md truncate">
                          {typeof row.data === 'object' 
                            ? JSON.stringify(row.data).substring(0, 100) + '...'
                            : String(row.data).substring(0, 100) + '...'}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                          {row.created_timestamp 
                            ? new Date(row.created_timestamp).toLocaleString()
                            : 'N/A'}
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

export default RawDataViewer
