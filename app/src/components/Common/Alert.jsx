import { AlertCircle, CheckCircle, Info, XCircle } from 'lucide-react'

function Alert({ type = 'info', title, children, className = '' }) {
  const types = {
    success: {
      bg: 'bg-green-50',
      border: 'border-green-200',
      text: 'text-green-800',
      icon: CheckCircle,
      iconColor: 'text-green-400',
    },
    error: {
      bg: 'bg-red-50',
      border: 'border-red-200',
      text: 'text-red-800',
      icon: XCircle,
      iconColor: 'text-red-400',
    },
    warning: {
      bg: 'bg-yellow-50',
      border: 'border-yellow-200',
      text: 'text-yellow-800',
      icon: AlertCircle,
      iconColor: 'text-yellow-400',
    },
    info: {
      bg: 'bg-blue-50',
      border: 'border-blue-200',
      text: 'text-blue-800',
      icon: Info,
      iconColor: 'text-blue-400',
    },
  }

  const config = types[type]
  const Icon = config.icon

  return (
    <div className={`${config.bg} ${config.border} border rounded-lg p-4 ${className}`}>
      <div className="flex">
        <div className="flex-shrink-0">
          <Icon className={`h-5 w-5 ${config.iconColor}`} />
        </div>
        <div className="ml-3">
          {title && (
            <h3 className={`text-sm font-medium ${config.text}`}>
              {title}
            </h3>
          )}
          <div className={`text-sm ${config.text} ${title ? 'mt-2' : ''}`}>
            {children}
          </div>
        </div>
      </div>
    </div>
  )
}

export default Alert
