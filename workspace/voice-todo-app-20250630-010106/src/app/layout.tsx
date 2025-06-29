import './globals.css'
import type { Metadata } from 'next'
import { Inter } from 'next/font/google'

const inter = Inter({ subsets: ['latin'] })

export const metadata: Metadata = {
  title: 'GameCorp - 革新的ゲーム会社',
  description: '次世代ゲーム体験を提供する革新的なゲーム開発会社',
  keywords: ['ゲーム', 'ゲーム開発', 'エンターテイメント', 'AI', 'ゲーム会社'],
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="ja">
      <body className={inter.className}>
        <div className="min-h-screen bg-gradient-to-br from-slate-900 via-purple-900 to-slate-900">
          {children}
        </div>
      </body>
    </html>
  )
}