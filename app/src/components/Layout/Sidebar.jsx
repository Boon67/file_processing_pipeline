import { NavLink } from 'react-router-dom'
import { 
  Upload, 
  Activity, 
  FolderOpen, 
  Database, 
  Settings 
} from 'lucide-react'

const navigation = [
  { name: 'Upload Files', to: '/upload', icon: Upload },
  { name: 'Processing Status', to: '/status', icon: Activity },
  { name: 'File Stages', to: '/stages', icon: FolderOpen },
  { name: 'Raw Data Viewer', to: '/raw-data', icon: Database },
  { name: 'Task Management', to: '/tasks', icon: Settings },
]

function Sidebar() {
  return (
    <div className="w-64 bg-white shadow-lg">
      <div className="flex flex-col h-full">
        <div className="flex items-center justify-center h-16 bg-primary-600">
          <span className="text-white text-xl font-bold">📁 Pipeline</span>
        </div>
        
        <nav className="flex-1 px-4 py-6 space-y-2">
          <div className="mb-4">
            <h2 className="px-4 text-xs font-semibold text-gray-500 uppercase tracking-wider">
              Navigation
            </h2>
          </div>
          
          {navigation.map((item) => (
            <NavLink
              key={item.name}
              to={item.to}
              className={({ isActive }) =>
                `flex items-center px-4 py-3 text-sm font-medium rounded-lg transition-colors ${
                  isActive
                    ? 'bg-primary-50 text-primary-700'
                    : 'text-gray-700 hover:bg-gray-100'
                }`
              }
            >
              <item.icon className="w-5 h-5 mr-3" />
              {item.name}
            </NavLink>
          ))}
        </nav>
        
        <div className="p-4 border-t">
          <p className="text-xs text-gray-500 text-center">
            Version 1.0.0
          </p>
        </div>
      </div>
    </div>
  )
}

export default Sidebar
