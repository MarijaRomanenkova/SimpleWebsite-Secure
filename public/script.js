        document.getElementById('inquiryForm').addEventListener('submit', async function(e) {
            e.preventDefault();
            
            const messageDiv = document.getElementById('message');
            const name = document.getElementById('name').value;
            const email = document.getElementById('email').value;
            const inquiry = document.getElementById('inquiry').value;
  
            try {
                const response = await fetch('/inquiries', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({ name, email, inquiry })
                });

                const data = await response.json();
                
                if (response.ok) {
                    messageDiv.className = 'message success';
                    messageDiv.textContent = 'Thank you! Your message has been sent successfully.';
                    document.getElementById('inquiryForm').reset();
                } else {
                    throw new Error(data.error || 'Failed to submit inquiry');
                }
            } catch (error) {
                messageDiv.className = 'message error';
                messageDiv.textContent = error.message;
            }
            
            messageDiv.style.display = 'block';
        });

