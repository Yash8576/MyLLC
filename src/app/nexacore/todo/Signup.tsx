// src/app/nexacore/todo/Signup.tsx

import React, { useState } from 'react';
import { auth } from './firebase';
import { createUserWithEmailAndPassword } from 'firebase/auth';

interface SignupProps {
    switchToLogin: () => void;
    onAuthSuccess: () => void;
}

function Signup({ switchToLogin, onAuthSuccess }: SignupProps) {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [error, setError] = useState('');

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setError('');

        if (password.length < 6) {
            setError('Password must be at least 6 characters.');
            return;
        }
        
        try {
            console.log('[Todo Signup] app name:', auth.app.name, 'projectId:', auth.app.options.projectId)
            const userCredential = await createUserWithEmailAndPassword(auth, email, password);

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

            onAuthSuccess();
        } catch (error: any) {
            console.error('[Todo Signup] error code:', error.code, 'message:', error.message)
            if (error.code === 'auth/email-already-in-use') {
                setError('This email address is already in use.');
            } else if (error.code === 'auth/invalid-email') {
                setError('The email address is not valid.');
            } else {
                setError(error.message);
            }
        }
    };

    return (
        <form className="auth-form" name="signup" method="POST" onSubmit={handleSubmit}>
            <h2>Sign Up</h2>
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
                autoComplete="new-password"
                placeholder="Password (min 6 characters)"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
            />
            <button type="submit">Sign Up</button>
            <p>
                Already have an account? 
                <span className="auth-link" onClick={switchToLogin}>Login here</span>
            </p>
        </form>
    );
}

export default Signup;
