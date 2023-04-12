const contentWrapper = document.querySelector('.main');
const modalWrapper = document.querySelector('.modal-wrapper');
const modalButtons = document.querySelectorAll('.modal-toggle');

modalButtons.forEach(button => {
    button.addEventListener('click', () => {
      contentWrapper.classList.toggle('modal-active');
      modalWrapper.classList.toggle('modal-active');
    });
  });