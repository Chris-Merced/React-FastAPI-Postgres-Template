import { useEffect, useState, type FormEvent } from 'react'

type User = {
  id: number
  email: string
}

function App() {
  const [token, setToken] = useState<string | null>(
    () => localStorage.getItem('token'),
  )
  const [user, setUser] = useState<User | null>(null)
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)

  // Whenever we have a token (fresh login, or one restored from
  // localStorage on page load), ask the API who it belongs to.
  useEffect(() => {
    if (!token) {
      setUser(null)
      return
    }

    fetch('/api/me', {
      headers: { Authorization: `Bearer ${token}` },
    }).then((res) => {
      if (!res.ok) {
        // Token expired or invalid - drop it and fall back to the login form.
        localStorage.removeItem('token')
        setToken(null)
        return
      }
      return res.json().then(setUser)
    })
  }, [token])

  async function handleSubmit(event: FormEvent) {
    event.preventDefault()
    setError(null)

    // FastAPI's OAuth2PasswordRequestForm expects form-urlencoded fields
    // named 'username' and 'password', not JSON.
    const body = new URLSearchParams({ username: email, password })
    const res = await fetch('/api/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body,
    })

    if (!res.ok) {
      setError('Incorrect email or password')
      return
    }

    const data = await res.json()
    localStorage.setItem('token', data.access_token)
    setToken(data.access_token)
  }

  function handleLogout() {
    localStorage.removeItem('token')
    setToken(null)
  }

  if (token && user) {
    return (
      <main>
        <p>Logged in as {user.email}</p>
        <button type="button" onClick={handleLogout}>
          Log out
        </button>
      </main>
    )
  }

  return (
    <main>
      <form onSubmit={handleSubmit}>
        <h1>Log in</h1>
        <label>
          Email
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
          />
        </label>
        <label>
          Password
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
        </label>
        {error && <p role="alert">{error}</p>}
        <button type="submit">Log in</button>
      </form>
    </main>
  )
}

export default App
