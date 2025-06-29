import { render, screen, fireEvent } from '@testing-library/react'
import '@testing-library/jest-dom'
import Header from '@/components/Header'

describe('Header Component', () => {
  test('ナビゲーションメニューが正しく表示される', () => {
    // Arrange & Act: コンポーネントをレンダリング
    render(<Header />)
    
    // Assert: 期待する要素が存在することを確認
    expect(screen.getByRole('navigation')).toBeInTheDocument()
    expect(screen.getByText('GameCorp')).toBeInTheDocument()
    expect(screen.getByText('About')).toBeInTheDocument()
    expect(screen.getByText('Games')).toBeInTheDocument()
    expect(screen.getByText('Team')).toBeInTheDocument()
    expect(screen.getByText('Contact')).toBeInTheDocument()
  })

  test('ナビゲーションリンクが適切なhref属性を持つ', () => {
    render(<Header />)
    
    expect(screen.getByRole('link', { name: 'About' })).toHaveAttribute('href', '#about')
    expect(screen.getByRole('link', { name: 'Games' })).toHaveAttribute('href', '#games')
    expect(screen.getByRole('link', { name: 'Team' })).toHaveAttribute('href', '#team')
    expect(screen.getByRole('link', { name: 'Contact' })).toHaveAttribute('href', '#contact')
  })

  test('モバイルメニューボタンが表示される', () => {
    render(<Header />)
    
    const mobileMenuButton = screen.getByRole('button', { name: /menu/i })
    expect(mobileMenuButton).toBeInTheDocument()
  })

  test('モバイルメニューが初期状態では非表示', () => {
    render(<Header />)
    
    const mobileMenu = screen.getByTestId('mobile-menu')
    expect(mobileMenu).toHaveClass('hidden')
  })

  test('モバイルメニューボタンをクリックするとメニューが表示される', () => {
    render(<Header />)
    
    const mobileMenuButton = screen.getByRole('button', { name: /menu/i })
    const mobileMenu = screen.getByTestId('mobile-menu')
    
    // 初期状態では非表示
    expect(mobileMenu).toHaveClass('hidden')
    
    // ボタンクリック
    fireEvent.click(mobileMenuButton)
    
    // メニューが表示される
    expect(mobileMenu).not.toHaveClass('hidden')
  })

  test('ロゴが適切に表示される', () => {
    render(<Header />)
    
    const logo = screen.getByText('GameCorp')
    expect(logo).toBeInTheDocument()
    expect(logo).toHaveClass('text-2xl', 'font-bold')
  })

  test('ダークテーマの背景色が適用される', () => {
    render(<Header />)
    
    const header = screen.getByRole('banner')
    expect(header).toHaveClass('bg-slate-900/95')
  })
})