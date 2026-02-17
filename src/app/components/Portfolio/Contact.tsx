'use client'
import React, { useState } from 'react';
import './styles/Contact.scss';
import emailjs from '@emailjs/browser';
import Box from '@mui/material/Box';
import Button from '@mui/material/Button';
import SendIcon from '@mui/icons-material/Send';
import TextField from '@mui/material/TextField';
import { ToastContainer, toast } from 'react-toastify';
import 'react-toastify/dist/ReactToastify.css';

function Contact() {

  const [name, setName] = useState<string>('');
  const [email, setEmail] = useState<string>('');
  const [message, setMessage] = useState<string>('');

  const [nameError, setNameError] = useState<boolean>(false);
  const [emailError, setEmailError] = useState<boolean>(false);
  const [messageError, setMessageError] = useState<boolean>(false);

  const sendEmail = (e: any) => {
    e.preventDefault();

    setNameError(name === '');
    setEmailError(email === '');
    setMessageError(message === '');

    if (name !== '' && email !== '' && message !== '') {
      const templateParams = {
        from_name: name,
        from_email: email,
        message: message,
        to_name: 'Yaswanth'
      };

      // Replace these with your EmailJS credentials
      emailjs.send(
        'service_areezfj',      // Replace with your EmailJS service ID
        'template_l43f259',     // Replace with your EmailJS template ID
        templateParams,
        'BtcitFxAR0Vv3nTGD'       // Replace with your EmailJS public key
      ).then(
        (response) => {
          console.log('SUCCESS!', response.status, response.text);
          toast.success('Message sent successfully! I will get back to you soon.', {
            position: "bottom-right",
            autoClose: 4000,
            hideProgressBar: false,
            closeOnClick: true,
            pauseOnHover: true,
            draggable: false,
          });
          setName('');
          setEmail('');
          setMessage('');
        },
        (error) => {
          console.log('FAILED...', error);
          toast.error('Failed to send message. Please try again or contact me directly at yd85086@uga.edu', {
            position: "bottom-right",
            autoClose: 6000,
            hideProgressBar: false,
            closeOnClick: true,
            pauseOnHover: true,
            draggable: false,
          });
        },
      );
    } else {
      toast.warning('Please fill in all fields before sending.', {
        position: "bottom-right",
        autoClose: 3000,
        hideProgressBar: false,
        closeOnClick: true,
        pauseOnHover: true,
        draggable: false,
      });
    }
  };

  return (
    <div id="contact">
      <ToastContainer
        position="bottom-right"
        newestOnTop={false}
        closeButton={true}
        rtl={false}
        pauseOnFocusLoss
        theme="dark"
        limit={3}
      />
      <div className="items-container">
        <div className="contact_wrapper">
          <h1>Contact Me</h1>
          <p>Got a project waiting to be realized? Let's collaborate and make it happen!</p>
          <Box
            component="form"
            noValidate
            autoComplete="off"
            className='contact-form'
          >
            <div className='form-flex'>
              <TextField
                required
                id="name-input"
                label="Your Name"
                placeholder="What's your name?"
                value={name}
                onChange={(e) => {
                  setName(e.target.value);
                }}
                error={nameError}
                helperText={nameError ? "Please enter your name" : ""}
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
                }}
              />
              <TextField
                required
                id="email-input"
                label="Email / Phone"
                placeholder="How can I reach you?"
                value={email}
                onChange={(e) => {
                  setEmail(e.target.value);
                }}
                error={emailError}
                helperText={emailError ? "Please enter your email or phone number" : ""}
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
                }}
              />
            </div>
            <TextField
              required
              id="message-input"
              label="Message"
              placeholder="Send me any inquiries or questions"
              multiline
              rows={10}
              className="body-form"
              value={message}
              onChange={(e) => {
                setMessage(e.target.value);
              }}
              error={messageError}
              helperText={messageError ? "Please enter the message" : ""}
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
              }}
            />
            <Button variant="contained" endIcon={<SendIcon />} onClick={sendEmail}>
              Send
            </Button>
          </Box>
        </div>
      </div>
    </div>
  );
}

export default Contact;
