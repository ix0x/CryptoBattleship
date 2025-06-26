'use client'

import { X } from 'lucide-react'

interface PlaceholderImageProps {
  width: number
  height: number
  text?: string
  className?: string
}

export default function PlaceholderImage({ 
  width, 
  height, 
  text = "Image", 
  className = "" 
}: PlaceholderImageProps) {
  return (
    <div 
      className={`bg-secondary border-2 border-red-accent border-dashed flex flex-col items-center justify-center ${className}`}
      style={{ width: `${width}px`, height: `${height}px` }}
    >
      <X className="h-8 w-8 text-error mb-2" />
      <span className="text-secondary-foreground font-medium text-center px-2">
        {text}
      </span>
      <span className="text-secondary-foreground/60 text-sm">
        {width} × {height}
      </span>
    </div>
  )
}