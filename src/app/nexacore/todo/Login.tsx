// src/app/nexacore/todo/Login.tsx

import React, { useState } from 'react';
import { auth } from './firebase';
import { signInWithEmailAndPassword } from 'firebase/auth';

interface LoginProps {
    switchToSignup: () => void;
    onAuthSuccess: (email: string) => void;
}

function Login({ switchToSignup, onAuthSuccess }: LoginProps) {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [error, setError] = useState('');

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setError('');

        try {
            const userCredential = await signInWithEmailAndPassword(auth, email, password);

            // Trigger browser's "Save Password" prompt via Credential Management API
            const w = window as any;
            if (typeof window !== 'undefined' && w.PasswordCredential) {
                const credential = new w.PasswordCredential({
                    id: email,
                    password: password,
                    name: email,
                });
                navigator.credentials.store(credential);
            }

            onAuthSuccess(userCredential.user.email || '');
        } catch (error: any) {
            if (error.code === 'auth/invalid-credential') {
                 setError('Invalid email or password. Please try again.');
            } else {
                setError(error.message);
            }
        }
    };

    return (
        <form className="auth-form" name="login" method="POST" onSubmit={handleSubmit}>
            <h2>Login</h2>
            {error && <p className="error">{error}</p>}
            <input
                type="email"
                name="email"
                autoComplete="email"
                placeholder="Email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
            />
            <input
                type="password"
                name="password"
                autoComplete="current-password"
                placeholder="Password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
            />
            <button type="submit">Login</button>
            <p>
                Don&apos;t have an account? 
                <span className="auth-link" onClick={switchToSignup}>Sign up here</span>
            </p>
        </form>
    );
}

export default Login;
