'use client'

import AdminDashboard from '@/components/AdminDashboard'

export default function AdminPage() {
  return (
    <div className="min-h-screen bg-background py-8">
      <div className="container mx-auto px-4">
        <AdminDashboard />
      </div>
    </div>
  )
}