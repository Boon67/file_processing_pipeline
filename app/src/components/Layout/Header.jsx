import { useQuery } from '@tanstack/react-query'
import { systemService } from '../../services/system'

function Header() {
  const { data: config } = useQuery({
    queryKey: ['config'],
    queryFn: systemService.getConfig,
  })

  return (
    <header className="bg-white shadow-sm">
      <div className="flex items-center justify-between px-6 py-4">
        <div>
          <h1 className="text-2xl font-bold text-primary-600">
            File Processing Pipeline
          </h1>
          <p className="text-sm text-gray-500">
            Bronze Layer Management
          </p>
        </div>
        <div className="flex items-center space-x-4">
          {config && (
            <div className="flex items-center space-x-2">
              <span className="text-sm text-gray-600">Mode:</span>
              <span className="px-2 py-1 text-xs font-semibold rounded-full bg-primary-100 text-primary-800">
                {config.mode}
              </span>
            </div>
          )}
        </div>
      </div>
    </header>
  )
}

export default Header
