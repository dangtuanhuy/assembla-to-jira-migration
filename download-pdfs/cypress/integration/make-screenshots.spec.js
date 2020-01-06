/// <reference types="Cypress" />

const tickets = require('../data/tickets.data.js');

const sel_ticket_number = '#ticketDetailsContainer > div > section > div > div > div.plr-l.width-30.width-33--vp-n.width-100--vp-s.fs-xs.lh-xxs > div.float-right.ws-nowrap';
const sel_ticket_to_pdf_button = '#ticket-to-pdf-button';

const username = 'kgish';
const password = 'secret';

context('Make screenshots', () => {
    beforeEach(() => {
        cy.visit('https://app.assembla.com/login');
        cy.get('#user_login').type(username);
        cy.get('#user_password').type(password);
        cy.get('#signin_button').click();
    });

    it('should be able to navigate to each ticket page and make screenshot', () => {
        tickets.forEach(ticket => {
            const ticket_number = ticket.ticket_number;
            const jira_key = ticket.jira_key;
            const url = `https://app.assembla.com/spaces/travelcommerce/tickets/${ticket_number}/details`;
            cy.visit(url);
            cy.get(sel_ticket_number).contains(`#${ticket_number}`);
            // Download the pdf
            cy.get(sel_ticket_to_pdf_button).click()
            // Make screenshot
            // const filename = `${ticket_number}-${jira_key}`;
            // cy.screenshot(filename, {capture: 'fullPage'});
        });
    });
});
