import React, { useState } from 'react';
import AppRouter from './AppRouter';

// Optional: Add a splash screen/onboarding component
const OnboardingScreen = ({ onComplete }) => {
  const [currentStep, setCurrentStep] = useState(0);
  
  const steps = [
    {
      title: "Welcome to SoundSpot",
      description: "Discover and share audio events happening around you in real-time.",
      icon: "🎵"
    },
    {
      title: "Record & Identify",
      description: "Record interesting sounds and our AI will help identify audio events automatically.",
      icon: "🎤"
    },
    {
      title: "Explore & Connect",
      description: "Find nearby audio experiences and connect with other sound enthusiasts.",
      icon: "🔍"
    },
    {
      title: "Private & Secure",
      description: "You're in control of your data. Share only what you want, when you want.",
      icon: "🔒"
    }
  ];
  
  const handleNext = () => {
    if (currentStep < steps.length - 1) {
      setCurrentStep(currentStep + 1);
    } else {
      onComplete();
    }
  };
  
  return (
    <div className="h-screen bg-gradient-to-b from-blue-500 to-purple-600 flex flex-col items-center justify-center text-white px-4">
      <div className="text-center max-w-md">
        <div className="text-6xl mb-6">{steps[currentStep].icon}</div>
        <h1 className="text-3xl font-bold mb-4">{steps[currentStep].title}</h1>
        <p className="text-lg mb-8 opacity-90">{steps[currentStep].description}</p>
        
        <div className="flex justify-center space-x-2 mb-8">
          {steps.map((_, index) => (
            <div 
              key={index} 
              className={`h-2 rounded-full ${
                index === currentStep ? 'w-8 bg-white' : 'w-2 bg-white bg-opacity-40'
              } transition-all`}
            />
          ))}
        </div>
        
        <button 
          onClick={handleNext} 
          className="bg-white text-blue-600 font-medium rounded-full px-8 py-3 shadow-lg hover:bg-opacity-90 transition-colors"
        >
          {currentStep < steps.length - 1 ? 'Next' : 'Get Started'}
        </button>
        
        {currentStep < steps.length - 1 && (
          <button 
            onClick={onComplete} 
            className="block mx-auto mt-4 text-white text-sm opacity-80 hover:opacity-100"
          >
            Skip
          </button>
        )}
      </div>
    </div>
  );
};

// Main App Component
const AudioEventApp = () => {
  const [hasOnboarded, setHasOnboarded] = useState(true); // Set to false to show onboarding
  
  const completeOnboarding = () => {
    setHasOnboarded(true);
  };
  
  if (!hasOnboarded) {
    return <OnboardingScreen onComplete={completeOnboarding} />;
  }
  
  return <AppRouter />;
};

export default AudioEventApp;
