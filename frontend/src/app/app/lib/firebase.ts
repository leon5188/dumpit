import { initializeApp, getApps, getApp } from "firebase/app";
import { getAuth } from "firebase/auth";

const firebaseConfig = {
	apiKey: "AIzaSyCUJreGDIJ_AkUeidNZgIov5-PK2VnyfJo",
	authDomain: "brainvent-9704a.firebaseapp.com",
	projectId: "brainvent-9704a",
	storageBucket: "brainvent-9704a.firebasestorage.app",
	messagingSenderId: "850734062900",
	appId: "1:850734062900:web:e1fb5b7f88e4d82a51d961",
	measurementId: "G-1C4E3302FQ",
};

export const firebaseApp = getApps().length ? getApp() : initializeApp(firebaseConfig);
export const firebaseAuth = getAuth(firebaseApp);
