import { Routes, Route, Navigate } from 'react-router-dom'
import Layout from './components/Layout/Layout'
import UploadFiles from './pages/UploadFiles'
import ProcessingStatus from './pages/ProcessingStatus'
import FileStages from './pages/FileStages'
import RawDataViewer from './pages/RawDataViewer'
import TaskManagement from './pages/TaskManagement'

function App() {
  return (
    <Routes>
      <Route path="/" element={<Layout />}>
        <Route index element={<Navigate to="/upload" replace />} />
        <Route path="upload" element={<UploadFiles />} />
        <Route path="status" element={<ProcessingStatus />} />
        <Route path="stages" element={<FileStages />} />
        <Route path="raw-data" element={<RawDataViewer />} />
        <Route path="tasks" element={<TaskManagement />} />
      </Route>
    </Routes>
  )
}

export default App
