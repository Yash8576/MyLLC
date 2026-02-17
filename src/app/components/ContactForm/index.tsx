'use client'
import { useState } from 'react'
import emailjs from '@emailjs/browser'
import Box from '@mui/material/Box'
import Button from '@mui/material/Button'
import SendIcon from '@mui/icons-material/Send'
import TextField from '@mui/material/TextField'
import { ToastContainer, toast } from 'react-toastify'
import 'react-toastify/dist/ReactToastify.css'

const ContactForm = () => {
  const [name, setName] = useState<string>('')
  const [email, setEmail] = useState<string>('')
  const [message, setMessage] = useState<string>('')

  const [nameError, setNameError] = useState<boolean>(false)
  const [emailError, setEmailError] = useState<boolean>(false)
  const [messageError, setMessageError] = useState<boolean>(false)

  const sendEmail = (e: React.FormEvent) => {
    e.preventDefault()

    setNameError(name === '')
    setEmailError(email === '')
    setMessageError(message === '')

    if (name !== '' && email !== '' && message !== '') {
      const templateParams = {
        from_name: name,
        from_email: email,
        message: message,
        to_name: 'Nexacore Team',
      }

      // Replace these with your EmailJS credentials
      emailjs
        .send(
          'service_areezfj', // EmailJS service ID
          'template_l43f259', // EmailJS template ID
          templateParams,
          'BtcitFxAR0Vv3nTGD' // EmailJS public key
        )
        .then(
          (response: any) => {
            console.log('SUCCESS!', response.status, response.text)
            toast.success(
              'Message sent successfully! We will get back to you soon.',
              {
                position: 'bottom-right',
                autoClose: 4000,
                hideProgressBar: false,
                closeOnClick: true,
                pauseOnHover: true,
                draggable: false,
              }
            )
            setName('')
            setEmail('')
            setMessage('')
          },
          (error: any) => {
            console.log('FAILED...', error)
            toast.error(
              'Failed to send message. Please try again or contact us directly.',
              {
                position: 'bottom-right',
                autoClose: 6000,
                hideProgressBar: false,
                closeOnClick: true,
                pauseOnHover: true,
                draggable: false,
              }
            )
          }
        )
    } else {
      toast.warning('Please fill in all fields before sending.', {
        position: 'bottom-right',
        autoClose: 3000,
        hideProgressBar: false,
        closeOnClick: true,
        pauseOnHover: true,
        draggable: false,
      })
    }
  }

  return (
    <section id='contact' className='bg-white py-20'>
      <ToastContainer
        position='bottom-right'
        newestOnTop={false}
        closeButton={true}
        rtl={false}
        pauseOnFocusLoss
        theme='light'
        limit={3}
      />
      <div className='container'>
        <div className='text-center mb-12'>
          <h2 className='text-midnight_text mb-4'>Contact Us</h2>
          <div className='w-20 h-1 bg-primary mx-auto mb-6'></div>
          <p className='text-black/70 text-lg max-w-3xl mx-auto'>
            Got a project waiting to be realized? Let&apos;s collaborate and
            make it happen!
          </p>
        </div>

        <div className='max-w-2xl mx-auto'>
          <Box
            component='form'
            onSubmit={sendEmail}
            noValidate
            autoComplete='off'
            className='space-y-6'>
            <div className='grid md:grid-cols-2 gap-6'>
              <TextField
                required
                id='name-input'
                label='Your Name'
                placeholder="What's your name?"
                value={name}
                onChange={(e: React.ChangeEvent<HTMLInputElement>) => {
                  setName(e.target.value)
                }}
                error={nameError}
                helperText={nameError ? 'Please enter your name' : ''}
                fullWidth
                sx={{
                  '& .MuiInputBase-root': {
                    backgroundColor: 'white',
                  },
                  '& .MuiInputBase-input': {
                    color: '#000',
                  },
                  '& .MuiInputLabel-root': {
                    color: '#666',
                  },
                  '& .MuiInputLabel-root.Mui-focused': {
                    color: '#5000ca',
                  },
                  '& .MuiOutlinedInput-root': {
                    '&:hover fieldset': {
                      borderColor: '#5000ca',
                    },
                    '&.Mui-focused fieldset': {
                      borderColor: '#5000ca',
                    },
                  },
                }}
              />
              <TextField
                required
                id='email-input'
                label='Email / Phone'
                placeholder='How can we reach you?'
                value={email}
                onChange={(e: React.ChangeEvent<HTMLInputElement>) => {
                  setEmail(e.target.value)
                }}
                error={emailError}
                helperText={
                  emailError ? 'Please enter your email or phone number' : ''
                }
                fullWidth
                sx={{
                  '& .MuiInputBase-root': {
                    backgroundColor: 'white',
                  },
                  '& .MuiInputBase-input': {
                    color: '#000',
                  },
                  '& .MuiInputLabel-root': {
                    color: '#666',
                  },
                  '& .MuiInputLabel-root.Mui-focused': {
                    color: '#5000ca',
                  },
                  '& .MuiOutlinedInput-root': {
                    '&:hover fieldset': {
                      borderColor: '#5000ca',
                    },
                    '&.Mui-focused fieldset': {
                      borderColor: '#5000ca',
                    },
                  },
                }}
              />
            </div>
            <TextField
              required
              id='message-input'
              label='Message'
              placeholder='Send us any inquiries or questions'
              multiline
              rows={10}
              value={message}
              onChange={(e: React.ChangeEvent<HTMLInputElement>) => {
                setMessage(e.target.value)
              }}
              error={messageError}
              helperText={messageError ? 'Please enter the message' : ''}
              fullWidth
              sx={{
                '& .MuiInputBase-root': {
                  backgroundColor: 'white',
                },
                '& .MuiInputBase-input': {
                  color: '#000',
                },
                '& .MuiInputLabel-root': {
                  color: '#666',
                },
                '& .MuiInputLabel-root.Mui-focused': {
                  color: '#5000ca',
                },
                '& .MuiOutlinedInput-root': {
                  '&:hover fieldset': {
                    borderColor: '#5000ca',
                  },
                  '&.Mui-focused fieldset': {
                    borderColor: '#5000ca',
                  },
                },
              }}
            />
            <Button
              type='submit'
              variant='contained'
              endIcon={<SendIcon />}
              fullWidth
              sx={{
                backgroundColor: '#5000ca',
                '&:hover': {
                  backgroundColor: '#4000a0',
                },
                padding: '12px',
                fontSize: '1.125rem',
                textTransform: 'none',
                fontWeight: 500,
              }}>
              Send Message
            </Button>
          </Box>
        </div>
      </div>
    </section>
  )
}

export default ContactForm
