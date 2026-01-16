import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { Settings, Play, RefreshCw } from 'lucide-react'
import { bronzeService } from '../services/bronze'
import Card from '../components/Common/Card'
import Button from '../components/Common/Button'
import Alert from '../components/Common/Alert'
import Loading from '../components/Common/Loading'

function TaskManagement() {
  const [executingTask, setExecutingTask] = useState(null)
  const queryClient = useQueryClient()

  const { data, isLoading, refetch } = useQuery({
    queryKey: ['tasks'],
    queryFn: bronzeService.getTasks,
    refetchInterval: 30000,
  })

  const executeTaskMutation = useMutation({
    mutationFn: (taskName) => bronzeService.executeTask(taskName),
    onSuccess: (_, taskName) => {
      queryClient.invalidateQueries(['tasks'])
      setExecutingTask(null)
      alert(`Task ${taskName} executed successfully!`)
    },
    onError: (error) => {
      alert(`Failed to execute task: ${error.message}`)
      setExecutingTask(null)
    },
  })

  const handleExecuteTask = (taskName) => {
    if (confirm(`Are you sure you want to execute task: ${taskName}?`)) {
      setExecutingTask(taskName)
      executeTaskMutation.mutate(taskName)
    }
  }

  const tasks = data?.tasks || []

  return (
    <div className="max-w-7xl mx-auto space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-bold text-gray-900">Task Management</h2>
          <p className="mt-2 text-gray-600">
            Monitor and control pipeline tasks
          </p>
        </div>
        <Button onClick={refetch} variant="secondary">
          <RefreshCw className="w-4 h-4 mr-2" />
          Refresh
        </Button>
      </div>

      <Alert type="info">
        Tasks are automated processes that run on a schedule. You can manually trigger them here for immediate execution.
      </Alert>

      {isLoading ? (
        <Loading text="Loading tasks..." />
      ) : (
        <div className="grid grid-cols-1 gap-6">
          {tasks.length === 0 ? (
            <Card>
              <div className="text-center py-12">
                <Settings className="w-12 h-12 text-gray-400 mx-auto mb-4" />
                <p className="text-gray-500">No tasks found</p>
              </div>
            </Card>
          ) : (
            tasks.map((task, index) => (
              <Card key={index}>
                <div className="flex items-center justify-between">
                  <div className="flex-1">
                    <div className="flex items-center space-x-3">
                      <Settings className="w-5 h-5 text-gray-400" />
                      <div>
                        <h3 className="text-lg font-semibold text-gray-900">
                          {task.name}
                        </h3>
                        {task.schedule && (
                          <p className="text-sm text-gray-500 mt-1">
                            Schedule: {task.schedule}
                          </p>
                        )}
                      </div>
                    </div>
                    
                    <div className="mt-4 grid grid-cols-2 md:grid-cols-4 gap-4">
                      <div>
                        <p className="text-xs text-gray-500">State</p>
                        <p className="text-sm font-medium text-gray-900 mt-1">
                          {task.state || 'N/A'}
                        </p>
                      </div>
                      <div>
                        <p className="text-xs text-gray-500">Last Run</p>
                        <p className="text-sm font-medium text-gray-900 mt-1">
                          {task.last_run ? new Date(task.last_run).toLocaleString() : 'Never'}
                        </p>
                      </div>
                      <div>
                        <p className="text-xs text-gray-500">Next Run</p>
                        <p className="text-sm font-medium text-gray-900 mt-1">
                          {task.next_run ? new Date(task.next_run).toLocaleString() : 'N/A'}
                        </p>
                      </div>
                      <div>
                        <p className="text-xs text-gray-500">Owner</p>
                        <p className="text-sm font-medium text-gray-900 mt-1">
                          {task.owner || 'N/A'}
                        </p>
                      </div>
                    </div>
                  </div>
                  
                  <div className="ml-6">
                    <Button
                      onClick={() => handleExecuteTask(task.name)}
                      variant="primary"
                      loading={executingTask === task.name}
                      disabled={executingTask !== null}
                    >
                      <Play className="w-4 h-4 mr-2" />
                      Execute Now
                    </Button>
                  </div>
                </div>
              </Card>
            ))
          )}
        </div>
      )}
    </div>
  )
}

export default TaskManagement
