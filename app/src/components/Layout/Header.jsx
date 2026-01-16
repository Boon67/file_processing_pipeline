import { useState, useEffect } from 'react'
import { useQuery } from '@tanstack/react-query'
import { systemService } from '../../services/system'
import { bronzeService } from '../../services/bronze'

function Header() {
  const [selectedTpa, setSelectedTpa] = useState('')

  const { data: config } = useQuery({
    queryKey: ['config'],
    queryFn: systemService.getConfig,
  })

  // Fetch available TPAs
  const { data: tpasData } = useQuery({
    queryKey: ['tpas'],
    queryFn: () => bronzeService.getTpas(),
  })

  const tpas = tpasData?.tpas || []

  // Set default TPA when data loads
  useEffect(() => {
    if (tpas.length > 0 && !selectedTpa) {
      setSelectedTpa(tpas[0].tpa_code)
    }
  }, [tpas, selectedTpa])

  // Store selected TPA in localStorage for global access
  useEffect(() => {
    if (selectedTpa) {
      localStorage.setItem('selectedTpa', selectedTpa)
      // Dispatch custom event to notify other components
      window.dispatchEvent(new CustomEvent('tpaChanged', { detail: selectedTpa }))
    }
  }, [selectedTpa])

  return (
    <header className="bg-slate-900 text-white shadow-lg">
      <div className="flex items-center justify-between px-6 py-3">
        {/* Left side: Logo and TPA selector */}
        <div className="flex items-center space-x-6">
          <div className="flex items-center space-x-2">
            <div className="w-8 h-8 bg-white rounded flex items-center justify-center">
              <svg className="w-5 h-5 text-slate-900" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4" />
              </svg>
            </div>
            <h1 className="text-xl font-bold">
              Snowflake Pipeline
            </h1>
          </div>

          {/* TPA Selector */}
          {tpas.length > 0 && (
            <div className="flex items-center">
              <select
                value={selectedTpa}
                onChange={(e) => setSelectedTpa(e.target.value)}
                className="bg-white text-slate-900 border-0 rounded-md px-4 py-2 text-sm font-medium focus:ring-2 focus:ring-blue-500 focus:outline-none cursor-pointer"
              >
                {tpas.map((tpa) => (
                  <option key={tpa.tpa_code} value={tpa.tpa_code}>
                    {tpa.tpa_name}
                  </option>
                ))}
              </select>
            </div>
          )}
        </div>

        {/* Right side: Config info */}
        <div className="flex items-center space-x-4">
          {config && (
            <div className="flex items-center space-x-2">
              <span className="text-sm text-slate-300">Mode:</span>
              <span className="px-2 py-1 text-xs font-semibold rounded-full bg-blue-500 text-white">
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
