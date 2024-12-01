import axios from 'axios';

const axiosBlob = axios.create({
	// Configuration
	baseURL: 'http://lb-337030458.us-east-1.elb.amazonaws.com',
	timeout: 30000,
	responseType:"blob"	
});

axiosBlob.interceptors.request.use(config => {
	const authToken = localStorage.getItem('authToken');
	if (authToken) {
		config.headers.Authorization = `Bearer ${authToken}`;
	}
	return config;
});


export default axiosBlob;